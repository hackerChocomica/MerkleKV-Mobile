#!/usr/bin/env bash
# Deterministic startup for a local Mosquitto test broker.
# Intended for CI or local dev when integration tests need a real broker
# instead of the embedded stub. Safe to run multiple times (idempotent).
#
# Environment overrides:
#   BROKER_PORT (default 1883)
#   COMPOSE_FILE (default ./docker-compose.basic.yml)
#   SERVICE_NAME (default mosquitto-test)
#   START_TIMEOUT (seconds, default 40)
#
# Exit codes:
#   0 success
#   1 prerequisite failure
#   2 startup timeout

set -euo pipefail

BROKER_PORT="${BROKER_PORT:-1883}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.basic.yml}"
SERVICE_NAME="${SERVICE_NAME:-mosquitto-test}"
START_TIMEOUT="${START_TIMEOUT:-40}"
RETRY_INTERVAL=2

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${BLUE}[start_test_broker]${NC} $*"; }
ok() { echo -e "${GREEN}[start_test_broker]${NC} $*"; }
warn() { echo -e "${YELLOW}[start_test_broker]${NC} $*"; }
err() { echo -e "${RED}[start_test_broker]${NC} $*" >&2; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Missing required command: $1"; exit 1; }; }

need_cmd docker
if command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker compose"
else
  err "Neither docker-compose nor docker compose available"
  exit 1
fi

# Fast path: port already open
if (command -v nc >/dev/null 2>&1 && nc -z localhost "$BROKER_PORT" 2>/dev/null) || \
   (timeout 1 bash -c ">/dev/tcp/127.0.0.1/${BROKER_PORT}" 2>/dev/null); then
  ok "Broker already listening on port ${BROKER_PORT} (skipping start)."
  exit 0
fi

log "Starting broker service '${SERVICE_NAME}' via ${COMPOSE_FILE}..."
${DOCKER_COMPOSE} -f "${COMPOSE_FILE}" up -d "${SERVICE_NAME}"

elapsed=0
while [ "$elapsed" -lt "$START_TIMEOUT" ]; do
  if (command -v nc >/dev/null 2>&1 && nc -z localhost "$BROKER_PORT" 2>/dev/null) || \
     (timeout 1 bash -c ">/dev/tcp/127.0.0.1/${BROKER_PORT}" 2>/dev/null); then
    ok "Broker port ${BROKER_PORT} is accepting connections after ${elapsed}s."
    # Optional health check using mosquitto_sub if present
    if command -v mosquitto_sub >/dev/null 2>&1; then
      # Probe the $SYS uptime topic (escaped so shell doesn't expand $S)
      if timeout 5 mosquitto_sub -h localhost -p "$BROKER_PORT" -t '\$SYS/broker/uptime' -C 1 >/dev/null 2>&1; then
        ok "Mosquitto responded to \$SYS uptime query."
      else
        warn "Mosquitto \$SYS uptime query did not return (continuing)."
      fi
    fi
    exit 0
  fi
  sleep "$RETRY_INTERVAL"
  elapsed=$((elapsed + RETRY_INTERVAL))
done

err "Broker did not become ready within ${START_TIMEOUT}s. Showing logs:"
${DOCKER_COMPOSE} -f "${COMPOSE_FILE}" logs --tail=50 "${SERVICE_NAME}" || true
exit 2
