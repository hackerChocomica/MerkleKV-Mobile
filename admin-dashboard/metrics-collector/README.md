# MerkleKV Metrics Collector

This service collects real-time device and system metrics from MerkleKV Mobile deployments via MQTT and exposes them via REST API for the admin dashboard.

## Features
- Subscribes to `merklekv/+/metrics` topics for all tenants
- Stores metrics per-tenant in Redis
- Exposes metrics via `/metrics/:tenantId` endpoint
- Health check at `/health`
- Periodic cleanup of old metrics (7 days)

## Usage

```
MQTT_BROKER=mqtt://localhost:1883
REDIS_URL=redis://localhost:6379
PORT=4000
node index.js
```

## Docker Compose Example

Add this service to your `docker-compose.yml`:

```yaml
  metrics-collector:
    build: ./metrics-collector
    container_name: merklekv-metrics-collector
    environment:
      - MQTT_BROKER=mqtt://mqtt-broker:1883
      - REDIS_URL=redis://merklekv-redis:6379
      - PORT=4000
    depends_on:
      - mqtt-broker
      - redis
    networks:
      - merklekv-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```
