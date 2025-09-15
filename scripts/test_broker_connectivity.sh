#!/bin/bash
set -e

# Simple integration test to verify broker connectivity
echo "Testing MQTT broker connectivity..."

# Test Mosquitto connectivity
echo "Testing Mosquitto..."
timeout 5 sh -c 'docker compose -f docker-compose.test.yml exec -T mosquitto-test mosquitto_pub -h localhost -t "test/integration" -m "test_message"' || {
    echo "❌ Mosquitto publish failed"
    exit 1
}

timeout 5 sh -c 'result=$(docker compose -f docker-compose.test.yml exec -T mosquitto-test mosquitto_sub -h localhost -t "test/integration" -C 1 &) && sleep 1 && docker compose -f docker-compose.test.yml exec -T mosquitto-test mosquitto_pub -h localhost -t "test/integration" -m "hello" && wait' || {
    echo "❌ Mosquitto subscribe/publish failed"
    exit 1
}

echo "✅ Mosquitto connectivity test passed"

# Test Toxiproxy connectivity
echo "Testing Toxiproxy..."
if curl -s -f http://localhost:8474/version >/dev/null; then
    echo "✅ Toxiproxy connectivity test passed"
else
    echo "❌ Toxiproxy connectivity failed"
    exit 1
fi

echo "🎉 All broker connectivity tests passed!"
echo "Integration test infrastructure is ready for development."