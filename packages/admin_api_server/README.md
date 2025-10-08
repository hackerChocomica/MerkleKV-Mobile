# Admin API Server (Minimal)

Exposes a small set of HTTP endpoints for a future admin dashboard. Mobile devs can consume these APIs to build their own UI.

## Endpoints

- GET /health → { status: "ok" }
- GET /stats/system[?dir=/path&maxEntries=5000]
  - memory.totalBytes, memory.availableBytes
  - cpu.utilizationPercentApprox (approx snapshot)
  - network.rxBytesTotal, network.txBytesTotal
  - storage.usedBytes (if dir param provided)
- GET /stats/process → current process RSS and raw CPU ticks (jiffies)
- GET /logs/recent[?limit=200] → recent buffered connection logs
- GET /logs/stream → Server-Sent Events stream of logs (Event: data: {json}\n\n)
- POST /logs/clear → clears buffered logs
- POST /config/validate → validate a minimal MQTT config; returns clientId on success

## Run locally

```bash
cd packages/admin_api_server
dart pub get
PORT=8080 dart run bin/server.dart
```

CORS is enabled by default for easy local development.
