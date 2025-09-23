require('dotenv').config();
const express = require('express');
const WebSocket = require('ws');
const winston = require('winston');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 4200;
const LOG_DIR = process.env.LOG_DIR || path.join(__dirname, 'logs');

const app = express();
app.use(cors());
app.use(express.json());

if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });

// Enhanced logger with file storage
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: path.join(LOG_DIR, 'combined.log') }),
    new winston.transports.File({ filename: path.join(LOG_DIR, 'error.log'), level: 'error' })
  ]
});

// Real-time log streaming
const wss = new WebSocket.Server({ port: PORT + 1 });
wss.on('connection', (ws) => {
  logger.info('Log stream client connected');
  ws.send(JSON.stringify({ type: 'connected', message: 'Log stream active' }));
});

// Broadcast log events to WebSocket clients
function broadcastLog(level, message, metadata = {}) {
  const logEntry = { level, message, timestamp: new Date().toISOString(), ...metadata };
  wss.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify({ type: 'log', data: logEntry }));
    }
  });
}

// Log aggregation endpoint
app.post('/logs/ingest', (req, res) => {
  const { deviceId, tenantId, level, message, metadata } = req.body;
  const logEntry = { deviceId, tenantId, level, message, metadata, timestamp: new Date() };
  
  // Store in file system (in production: use ELK stack)
  const logFile = path.join(LOG_DIR, `${tenantId}.log`);
  fs.appendFileSync(logFile, JSON.stringify(logEntry) + '\n');
  
  // Broadcast to real-time viewers
  broadcastLog(level, message, { deviceId, tenantId, ...metadata });
  
  logger.info('Log ingested', logEntry);
  res.json({ success: true });
});

// Query logs
app.get('/logs/:tenantId', (req, res) => {
  const { tenantId } = req.params;
  const { level, start, end, limit = 100 } = req.query;
  
  const logFile = path.join(LOG_DIR, `${tenantId}.log`);
  if (!fs.existsSync(logFile)) return res.json({ success: true, logs: [] });
  
  const logs = fs.readFileSync(logFile, 'utf-8')
    .split('\n')
    .filter(line => line.trim())
    .map(line => JSON.parse(line))
    .filter(log => {
      if (level && log.level !== level) return false;
      if (start && new Date(log.timestamp) < new Date(start)) return false;
      if (end && new Date(log.timestamp) > new Date(end)) return false;
      return true;
    })
    .slice(-limit);
  
  res.json({ success: true, logs });
});

// Connection diagnostics
app.post('/diagnostics/connection', (req, res) => {
  const { host, port, protocol = 'mqtt' } = req.body;
  
  // Simulated connection test (in production: implement actual connectivity check)
  const result = {
    host,
    port,
    protocol,
    status: Math.random() > 0.2 ? 'success' : 'failed',
    latency: Math.floor(Math.random() * 100) + 10,
    timestamp: new Date()
  };
  
  logger.info('Connection diagnostic performed', result);
  res.json({ success: true, result });
});

// Data verification
app.post('/diagnostics/data-integrity', (req, res) => {
  const { tenantId, deviceId, dataHash } = req.body;
  
  // Simulated data integrity check
  const result = {
    tenantId,
    deviceId,
    dataHash,
    verified: Math.random() > 0.1,
    corruptedBlocks: Math.random() > 0.8 ? Math.floor(Math.random() * 5) : 0,
    timestamp: new Date()
  };
  
  logger.info('Data integrity check performed', result);
  res.json({ success: true, result });
});

// Alert management
const alerts = [];

app.get('/alerts', (req, res) => {
  const { tenantId, severity } = req.query;
  let filteredAlerts = alerts;
  
  if (tenantId) filteredAlerts = filteredAlerts.filter(a => a.tenantId === tenantId);
  if (severity) filteredAlerts = filteredAlerts.filter(a => a.severity === severity);
  
  res.json({ success: true, alerts: filteredAlerts });
});

app.post('/alerts', (req, res) => {
  const alert = {
    id: Date.now().toString(),
    ...req.body,
    timestamp: new Date(),
    acknowledged: false
  };
  alerts.push(alert);
  
  // Broadcast alert to WebSocket clients
  wss.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify({ type: 'alert', data: alert }));
    }
  });
  
  logger.warn('Alert created', alert);
  res.json({ success: true, alert });
});

app.patch('/alerts/:id/acknowledge', (req, res) => {
  const { id } = req.params;
  const alert = alerts.find(a => a.id === id);
  if (!alert) return res.status(404).json({ error: 'Alert not found' });
  
  alert.acknowledged = true;
  alert.acknowledgedAt = new Date();
  
  logger.info('Alert acknowledged', { id });
  res.json({ success: true, alert });
});

// Health endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    services: {
      logAggregation: 'active',
      alertManagement: 'active',
      diagnostics: 'active',
      websocket: `${wss.clients.size} clients connected`
    },
    timestamp: new Date() 
  });
});

const server = app.listen(PORT, () => {
  logger.info(`Troubleshooting Tools running on port ${PORT}`);
  logger.info(`WebSocket log stream on port ${PORT + 1}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    wss.close();
    process.exit(0);
  });
});