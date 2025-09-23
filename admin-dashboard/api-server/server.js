const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');

const app = express();
const PORT = 3001;
const JWT_SECRET = 'test-secret-key';

// Middleware
app.use(cors());
app.use(express.json());

// Mock data
const mockUser = {
  id: '1',
  email: 'admin@merklekv.com',
  firstName: 'Admin',
  lastName: 'User',
  role: 'admin',
  tenantId: 'tenant-1',
  permissions: ['read', 'write', 'admin'],
  lastLogin: new Date(),
  isActive: true,
  createdAt: new Date(),
  updatedAt: new Date()
};

// Auth endpoints
app.post('/auth/login', (req, res) => {
  const { email, password } = req.body;
  
  if (email === 'admin@merklekv.com' && password === 'admin123') {
    const accessToken = jwt.sign({ userId: mockUser.id }, JWT_SECRET, { expiresIn: '1h' });
    const refreshToken = jwt.sign({ userId: mockUser.id }, JWT_SECRET, { expiresIn: '7d' });
    
    res.json({
      success: true,
      data: {
        user: mockUser,
        accessToken,
        refreshToken
      },
      timestamp: new Date()
    });
  } else {
    res.status(401).json({
      success: false,
      error: {
        message: 'Invalid credentials',
        code: '401',
        timestamp: new Date()
      }
    });
  }
});

app.post('/auth/refresh', (req, res) => {
  const { refreshToken } = req.body;
  
  try {
    jwt.verify(refreshToken, JWT_SECRET);
    const newAccessToken = jwt.sign({ userId: mockUser.id }, JWT_SECRET, { expiresIn: '1h' });
    const newRefreshToken = jwt.sign({ userId: mockUser.id }, JWT_SECRET, { expiresIn: '7d' });
    
    res.json({
      success: true,
      data: {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken
      },
      timestamp: new Date()
    });
  } catch (error) {
    res.status(401).json({
      success: false,
      error: {
        message: 'Invalid refresh token',
        code: '401',
        timestamp: new Date()
      }
    });
  }
});

app.get('/auth/me', (req, res) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: {
        message: 'No token provided',
        code: '401',
        timestamp: new Date()
      }
    });
  }
  
  const token = authHeader.substring(7);
  
  try {
    jwt.verify(token, JWT_SECRET);
    res.json({
      success: true,
      data: mockUser,
      timestamp: new Date()
    });
  } catch (error) {
    res.status(401).json({
      success: false,
      error: {
        message: 'Invalid token',
        code: '401',
        timestamp: new Date()
      }
    });
  }
});

// Dashboard stats
app.get('/dashboard/stats', (req, res) => {
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

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date(),
    service: 'merklekv-api'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 MerkleKV API Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🔐 Login credentials: admin@merklekv.com / admin123`);
});