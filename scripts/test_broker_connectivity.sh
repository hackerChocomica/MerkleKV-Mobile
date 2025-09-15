#!/bin/bash
set -e

# Allow override of compose file via environment variable or first argument
COMPOSE_FILE_PATH="${COMPOSE_FILE:-${1:-docker-compose.test.yml}}"

echo "Testing MQTT broker connectivity..."
echo "Using compose file: $COMPOSE_FILE_PATH"

# Test Mosquitto basic connectivity
echo "Testing Mosquitto..."
if docker compose -f "$COMPOSE_FILE_PATH" exec -T mosquitto-test mosquitto_pub -h localhost -t "test/simple" -m "hello" 2>/dev/null; then
    echo "✅ Mosquitto publish test passed"
else
    echo "❌ Mosquitto publish failed"
    exit 1
fi

# Test Toxiproxy connectivity
echo "Testing Toxiproxy..."
if curl -s -f http://localhost:8474/version >/dev/null 2>&1; then
    echo "✅ Toxiproxy connectivity test passed"
else
    echo "❌ Toxiproxy connectivity failed"
    exit 1
fi

echo "🎉 All broker connectivity tests passed!"