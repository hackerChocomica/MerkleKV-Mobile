const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'test-secret-key';

// Enhanced middleware
app.use(cors());
app.use(express.json());

// Rate limiting
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per window
  message: { error: 'Too many authentication attempts, please try again later' }
});

app.use('/auth', authLimiter);

// Audit logging
const auditLog = (action, userId, details = {}) => {
  const logEntry = {
    timestamp: new Date().toISOString(),
    action,
    userId,
    ip: details.ip,
    userAgent: details.userAgent,
    success: details.success,
    details
  };
  
  // Write to audit log file (in production: use proper audit system)
  const logPath = path.join(__dirname, 'audit.log');
  fs.appendFileSync(logPath, JSON.stringify(logEntry) + '\n');
  console.log('AUDIT:', logEntry);
};

// Password validation
function validatePassword(password) {
  const minLength = 8;
  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasNumber = /\d/.test(password);
  const hasSpecial = /[!@#$%^&*]/.test(password);
  
  if (password.length < minLength) return { valid: false, message: 'Password must be at least 8 characters' };
  if (!hasUpper) return { valid: false, message: 'Password must contain uppercase letter' };
  if (!hasLower) return { valid: false, message: 'Password must contain lowercase letter' };
  if (!hasNumber) return { valid: false, message: 'Password must contain number' };
  if (!hasSpecial) return { valid: false, message: 'Password must contain special character' };
  
  return { valid: true };
}

// Mock users with hashed passwords
const users = {
  'admin@merklekv.com': {
    id: '1',
    email: 'admin@merklekv.com',
    firstName: 'Admin',
    lastName: 'User',
    role: 'super-admin',
    tenantId: 'tenant-1',
    permissions: ['read', 'write', 'admin', 'super-admin'],
    passwordHash: bcrypt.hashSync('admin123', 10),
    twoFactorEnabled: false,
    lastLogin: new Date(),
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
    loginAttempts: 0,
    lockedUntil: null
  }
};

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      auditLog('token_verification_failed', null, { 
        ip: req.ip, 
        userAgent: req.get('User-Agent'),
        success: false 
      });
      return res.status(403).json({ error: 'Invalid token' });
    }
    req.user = user;
    next();
  });
};

// Enhanced auth endpoints
app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  const user = users[email];
  
  if (!user || user.lockedUntil && user.lockedUntil > new Date()) {
    auditLog('login_failed', email, { 
      ip: req.ip, 
      userAgent: req.get('User-Agent'),
      reason: 'user_not_found_or_locked',
      success: false 
    });
    return res.status(401).json({
      success: false,
      error: { message: 'Invalid credentials', code: '401' }
    });
  }
  
  const passwordValid = await bcrypt.compare(password, user.passwordHash);
  
  if (!passwordValid) {
    user.loginAttempts = (user.loginAttempts || 0) + 1;
    if (user.loginAttempts >= 5) {
      user.lockedUntil = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes
    }
    
    auditLog('login_failed', user.id, { 
      ip: req.ip, 
      userAgent: req.get('User-Agent'),
      reason: 'invalid_password',
      attempts: user.loginAttempts,
      success: false 
    });
    
    return res.status(401).json({
      success: false,
      error: { message: 'Invalid credentials', code: '401' }
    });
  }
  
  // Reset login attempts on successful login
  user.loginAttempts = 0;
  user.lockedUntil = null;
  user.lastLogin = new Date();
  
  const accessToken = jwt.sign({ userId: user.id, email: user.email }, JWT_SECRET, { expiresIn: '1h' });
  const refreshToken = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '7d' });
  
  auditLog('login_success', user.id, { 
    ip: req.ip, 
    userAgent: req.get('User-Agent'),
    success: true 
  });
  
  res.json({
    success: true,
    data: {
      user: { ...user, passwordHash: undefined },
      accessToken,
      refreshToken
    },
    timestamp: new Date()
  });
});

app.post('/auth/refresh', (req, res) => {
  const { refreshToken } = req.body;
  
  try {
    const decoded = jwt.verify(refreshToken, JWT_SECRET);
    const newAccessToken = jwt.sign({ userId: decoded.userId }, JWT_SECRET, { expiresIn: '1h' });
    const newRefreshToken = jwt.sign({ userId: decoded.userId }, JWT_SECRET, { expiresIn: '7d' });
    
    auditLog('token_refresh', decoded.userId, { 
      ip: req.ip, 
      userAgent: req.get('User-Agent'),
      success: true 
    });
    
    res.json({
      success: true,
      data: {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken
      },
      timestamp: new Date()
    });
  } catch (error) {
    auditLog('token_refresh_failed', null, { 
      ip: req.ip, 
      userAgent: req.get('User-Agent'),
      success: false 
    });
    
    res.status(401).json({
      success: false,
      error: { message: 'Invalid refresh token', code: '401' }
    });
  }
});

app.get('/auth/me', authenticateToken, (req, res) => {
  const user = Object.values(users).find(u => u.id === req.user.userId);
  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }
  
  res.json({
    success: true,
    data: { ...user, passwordHash: undefined },
    timestamp: new Date()
  });
});

// Password change with validation
app.post('/auth/change-password', authenticateToken, async (req, res) => {
  const { oldPassword, newPassword } = req.body;
  const user = Object.values(users).find(u => u.id === req.user.userId);
  
  if (!user) return res.status(404).json({ error: 'User not found' });
  
  const oldPasswordValid = await bcrypt.compare(oldPassword, user.passwordHash);
  if (!oldPasswordValid) {
    auditLog('password_change_failed', user.id, { 
      ip: req.ip, 
      reason: 'invalid_old_password',
      success: false 
    });
    return res.status(400).json({ error: 'Invalid old password' });
  }
  
  const passwordValidation = validatePassword(newPassword);
  if (!passwordValidation.valid) {
    return res.status(400).json({ error: passwordValidation.message });
  }
  
  user.passwordHash = await bcrypt.hash(newPassword, 10);
  user.updatedAt = new Date();
  
  auditLog('password_change_success', user.id, { 
    ip: req.ip, 
    success: true 
  });
  
  res.json({ success: true, message: 'Password changed successfully' });
});

// 2FA setup (mock implementation)
app.post('/auth/2fa/setup', authenticateToken, (req, res) => {
  const user = Object.values(users).find(u => u.id === req.user.userId);
  const secret = 'JBSWY3DPEHPK3PXP'; // Mock secret
  const qrCode = `otpauth://totp/MerkleKV:${user.email}?secret=${secret}&issuer=MerkleKV`;
  
  auditLog('2fa_setup_initiated', user.id, { 
    ip: req.ip, 
    success: true 
  });
  
  res.json({ success: true, data: { qrCode, secret } });
});

app.post('/auth/2fa/verify', authenticateToken, (req, res) => {
  const { code } = req.body;
  const user = Object.values(users).find(u => u.id === req.user.userId);
  
  // Mock verification (in production: use authenticator library)
  const isValid = code === '123456';
  
  if (isValid) {
    user.twoFactorEnabled = true;
    auditLog('2fa_enabled', user.id, { 
      ip: req.ip, 
      success: true 
    });
    res.json({ success: true, message: '2FA enabled successfully' });
  } else {
    auditLog('2fa_verification_failed', user.id, { 
      ip: req.ip, 
      success: false 
    });
    res.status(400).json({ error: 'Invalid 2FA code' });
  }
});

// Dashboard stats
app.get('/dashboard/stats', authenticateToken, (req, res) => {
  res.json({
    success: true,
    data: {
      totalTenants: 24,
      activeDevices: 156,
      activeAlerts: 3,
      systemHealth: 'good'
    },
    timestamp: new Date()
  });
});

// Audit log endpoint (admin only)
app.get('/admin/audit-logs', authenticateToken, (req, res) => {
  const user = Object.values(users).find(u => u.id === req.user.userId);
  if (!user.permissions.includes('super-admin')) {
    return res.status(403).json({ error: 'Insufficient permissions' });
  }
  
  try {
    const auditLogPath = path.join(__dirname, 'audit.log');
    if (!fs.existsSync(auditLogPath)) {
      return res.json({ success: true, logs: [] });
    }
    
    const logs = fs.readFileSync(auditLogPath, 'utf-8')
      .split('\n')
      .filter(line => line.trim())
      .map(line => JSON.parse(line))
      .slice(-100); // Last 100 entries
    
    res.json({ success: true, logs });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve audit logs' });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date(),
    service: 'merklekv-api',
    features: {
      authentication: 'enabled',
      auditLogging: 'enabled',
      rateLimiting: 'enabled',
      passwordPolicies: 'enabled',
      twoFactor: 'supported'
    }
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Enhanced MerkleKV API Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🔐 Login credentials: admin@merklekv.com / admin123`);
  console.log(`🛡️ Security features: Rate limiting, Audit logging, 2FA, Password policies`);
});