require('dotenv').config();
const mqtt = require('mqtt');
const express = require('express');
const redis = require('redis');
const winston = require('winston');
const cron = require('node-cron');
const cors = require('cors');

const MQTT_BROKER = process.env.MQTT_BROKER || 'mqtt://localhost:1883';
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const PORT = process.env.PORT || 4000;

const app = express();
app.use(cors());
app.use(express.json());

// Logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console()]
});

// Redis client
const redisClient = redis.createClient({ url: REDIS_URL });
redisClient.connect();

// MQTT client
const mqttClient = mqtt.connect(MQTT_BROKER);

mqttClient.on('connect', () => {
  logger.info('Connected to MQTT broker');
  mqttClient.subscribe('merklekv/+/metrics');
});

mqttClient.on('message', async (topic, message) => {
  try {
    const [_, tenantId, type] = topic.split('/');
    if (type === 'metrics') {
      const metrics = JSON.parse(message.toString());
      // Store metrics in Redis (per-tenant)
      await redisClient.hSet(`metrics:${tenantId}`, Date.now(), JSON.stringify(metrics));
      logger.info(`Metrics received for tenant ${tenantId}`);
    }
  } catch (err) {
    logger.error('Error processing MQTT message', err);
  }
});

// Expose metrics via REST
app.get('/metrics/:tenantId', async (req, res) => {
  const { tenantId } = req.params;
  const data = await redisClient.hGetAll(`metrics:${tenantId}`);
  const result = Object.entries(data).map(([ts, val]) => ({ timestamp: Number(ts), ...JSON.parse(val) }));
  res.json({ success: true, data: result });
});

// Health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date() });
});

// Periodic cleanup (keep 7 days)
cron.schedule('0 0 * * *', async () => {
  const keys = await redisClient.keys('metrics:*');
  const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000;
  for (const key of keys) {
    const entries = await redisClient.hGetAll(key);
    for (const ts of Object.keys(entries)) {
      if (Number(ts) < cutoff) await redisClient.hDel(key, ts);
    }
  }
  logger.info('Old metrics cleaned up');
});

app.listen(PORT, () => {
  logger.info(`Metrics Collector running on port ${PORT}`);
});
