require('dotenv').config();
const express = require('express');
const Ajv = require('ajv');
const winston = require('winston');
const cron = require('node-cron');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 4100;
const CONFIG_DIR = process.env.CONFIG_DIR || path.join(__dirname, 'storage');
const SCHEMA_PATH = process.env.SCHEMA_PATH || path.join(__dirname, 'schemas', 'merklekv-config.schema.json');

const app = express();
app.use(cors());
app.use(express.json());

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console()]
});

if (!fs.existsSync(CONFIG_DIR)) fs.mkdirSync(CONFIG_DIR, { recursive: true });

const ajv = new Ajv();
const configSchema = JSON.parse(fs.readFileSync(SCHEMA_PATH, 'utf-8'));
const validate = ajv.compile(configSchema);

// Versioned config storage
function getConfigPath(tenantId, version) {
  return path.join(CONFIG_DIR, `${tenantId}.${version}.json`);
}

// List all versions
function listVersions(tenantId) {
  return fs.readdirSync(CONFIG_DIR)
    .filter(f => f.startsWith(tenantId + '.'))
    .map(f => f.split('.')[1]);
}

// Get latest version
function getLatestVersion(tenantId) {
  const versions = listVersions(tenantId);
  return versions.length ? versions.sort().reverse()[0] : null;
}

// API: Get config
app.get('/config/:tenantId', (req, res) => {
  const { tenantId } = req.params;
  const version = getLatestVersion(tenantId);
  if (!version) return res.status(404).json({ error: 'No config found' });
  const config = JSON.parse(fs.readFileSync(getConfigPath(tenantId, version)));
  res.json({ success: true, version, config });
});

// API: List versions
app.get('/config/:tenantId/versions', (req, res) => {
  const { tenantId } = req.params;
  res.json({ success: true, versions: listVersions(tenantId) });
});

// API: Deploy config (with validation)
app.post('/config/:tenantId', (req, res) => {
  const { tenantId } = req.params;
  const config = req.body;
  if (!validate(config)) {
    return res.status(400).json({ success: false, errors: validate.errors });
  }
  const version = Date.now().toString();
  fs.writeFileSync(getConfigPath(tenantId, version), JSON.stringify(config, null, 2));
  logger.info(`Config deployed for ${tenantId} version ${version}`);
  res.json({ success: true, version });
});

// API: Rollback
app.post('/config/:tenantId/rollback', (req, res) => {
  const { tenantId } = req.params;
  const { version } = req.body;
  if (!fs.existsSync(getConfigPath(tenantId, version))) {
    return res.status(404).json({ error: 'Version not found' });
  }
  const config = JSON.parse(fs.readFileSync(getConfigPath(tenantId, version)));
  const newVersion = Date.now().toString();
  fs.writeFileSync(getConfigPath(tenantId, newVersion), JSON.stringify(config, null, 2));
  logger.info(`Config rollback for ${tenantId} to version ${version}`);
  res.json({ success: true, version: newVersion });
});

// Health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date() });
});

app.listen(PORT, () => {
  logger.info(`Config Manager running on port ${PORT}`);
});
