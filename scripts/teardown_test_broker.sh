#!/usr/bin/env bash
# Teardown companion for start_test_broker.sh.
# Stops and removes the broker container ONLY if it was auto-started
# (detected via .broker_auto_started marker).

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.basic.yml}"
SERVICE_NAME="${SERVICE_NAME:-mosquitto-test}"
MARKER_FILE=".broker_auto_started"

if command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker compose"
else
  echo "[teardown_test_broker] docker-compose not available; nothing to do" >&2
  exit 0
fi

if [ ! -f "$MARKER_FILE" ]; then
  echo "[teardown_test_broker] No marker file; assuming broker not auto-started. Skipping." >&2
  exit 0
fi

echo "[teardown_test_broker] Stopping auto-started broker ${SERVICE_NAME}..."
${DOCKER_COMPOSE} -f "$COMPOSE_FILE" rm -sfv "$SERVICE_NAME" || true
rm -f "$MARKER_FILE" || true
echo "[teardown_test_broker] Done."
