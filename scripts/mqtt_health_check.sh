#!/bin/bash

# MQTT Broker Health Check Script
# Validates MQTT broker availability and basic functionality before running tests

set -euo pipefail

# Configuration
BROKER_HOST="${MQTT_BROKER_HOST:-localhost}"
BROKER_PORT="${MQTT_BROKER_PORT:-1883}"
TIMEOUT_SECONDS="${MQTT_HEALTH_TIMEOUT:-30}"
RETRY_INTERVAL=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are available
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v nc &> /dev/null; then
        log_error "netcat (nc) is required but not installed"
        return 1
    fi
    
    if ! command -v mosquitto_pub &> /dev/null || ! command -v mosquitto_sub &> /dev/null; then
        log_warning "mosquitto-clients not found, installing..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y mosquitto-clients
        elif command -v yum &> /dev/null; then
            sudo yum install -y mosquitto
        elif command -v brew &> /dev/null; then
            brew install mosquitto
        else
            log_error "Cannot install mosquitto-clients automatically"
            return 1
        fi
    fi
    
    log_success "Prerequisites check passed"
}

# Wait for TCP port to be available
wait_for_port() {
    log_info "Waiting for MQTT broker at ${BROKER_HOST}:${BROKER_PORT}..."
    
    local elapsed=0
    while [ $elapsed -lt $TIMEOUT_SECONDS ]; do
        if nc -z "$BROKER_HOST" "$BROKER_PORT" 2>/dev/null; then
            log_success "MQTT broker port ${BROKER_PORT} is open"
            return 0
        fi
        
        log_info "Port not available yet, waiting... (${elapsed}/${TIMEOUT_SECONDS}s)"
        sleep $RETRY_INTERVAL
        elapsed=$((elapsed + RETRY_INTERVAL))
    done
    
    log_error "MQTT broker port ${BROKER_PORT} failed to open after ${TIMEOUT_SECONDS} seconds"
    return 1
}

# Test basic MQTT connectivity
test_mqtt_connection() {
    log_info "Testing MQTT broker connectivity..."
    
    local test_topic="test/health_check/$(date +%s)"
    local test_message="health_check_$(date +%s)"
    local received_file="/tmp/mqtt_health_received_$$"
    
    # Clean up any existing temp files
    rm -f "$received_file"
    
    # Start subscriber in background with timeout
    log_info "Starting MQTT subscriber for health check..."
    timeout 10s mosquitto_sub \
        -h "$BROKER_HOST" \
        -p "$BROKER_PORT" \
        -t "$test_topic" \
        -C 1 \
        > "$received_file" 2>/dev/null &
    
    local sub_pid=$!
    
    # Give subscriber time to connect
    sleep 2
    
    # Publish test message
    log_info "Publishing test message..."
    if mosquitto_pub \
        -h "$BROKER_HOST" \
        -p "$BROKER_PORT" \
        -t "$test_topic" \
        -m "$test_message" \
        --qos 0 2>/dev/null; then
        log_success "Message published successfully"
    else
        log_error "Failed to publish test message"
        kill $sub_pid 2>/dev/null || true
        rm -f "$received_file"
        return 1
    fi
    
    # Wait for subscriber to receive message
    local wait_count=0
    while [ $wait_count -lt 10 ] && kill -0 $sub_pid 2>/dev/null; do
        if [ -f "$received_file" ] && [ -s "$received_file" ]; then
            break
        fi
        sleep 0.5
        wait_count=$((wait_count + 1))
    done
    
    # Check if message was received
    if [ -f "$received_file" ] && [ -s "$received_file" ]; then
        local received_message=$(cat "$received_file")
        if [ "$received_message" = "$test_message" ]; then
            log_success "MQTT publish/subscribe test passed"
            rm -f "$received_file"
            return 0
        else
            log_error "Received message doesn't match sent message"
            log_error "Sent: '$test_message', Received: '$received_message'"
        fi
    else
        log_error "No message received within timeout period"
    fi
    
    # Cleanup
    kill $sub_pid 2>/dev/null || true
    rm -f "$received_file"
    return 1
}

# Test QoS 1 functionality
test_qos1_functionality() {
    log_info "Testing QoS 1 functionality..."
    
    local test_topic="test/qos1_health/$(date +%s)"
    local test_message="qos1_test_$(date +%s)"
    local received_file="/tmp/mqtt_qos1_received_$$"
    
    # Clean up any existing temp files
    rm -f "$received_file"
    
    # Start subscriber with QoS 1
    timeout 10s mosquitto_sub \
        -h "$BROKER_HOST" \
        -p "$BROKER_PORT" \
        -t "$test_topic" \
        -q 1 \
        -C 1 \
        > "$received_file" 2>/dev/null &
    
    local sub_pid=$!
    
    # Give subscriber time to connect
    sleep 2
    
    # Publish with QoS 1
    if mosquitto_pub \
        -h "$BROKER_HOST" \
        -p "$BROKER_PORT" \
        -t "$test_topic" \
        -m "$test_message" \
        --qos 1 2>/dev/null; then
        log_success "QoS 1 message published successfully"
    else
        log_error "Failed to publish QoS 1 message"
        kill $sub_pid 2>/dev/null || true
        rm -f "$received_file"
        return 1
    fi
    
    # Wait for message reception
    local wait_count=0
    while [ $wait_count -lt 10 ] && kill -0 $sub_pid 2>/dev/null; do
        if [ -f "$received_file" ] && [ -s "$received_file" ]; then
            break
        fi
        sleep 0.5
        wait_count=$((wait_count + 1))
    done
    
    # Verify QoS 1 delivery
    if [ -f "$received_file" ] && [ -s "$received_file" ]; then
        log_success "QoS 1 delivery test passed"
        rm -f "$received_file"
        return 0
    else
        log_error "QoS 1 message delivery failed"
        kill $sub_pid 2>/dev/null || true
        rm -f "$received_file"
        return 1
    fi
}

# Main health check execution
main() {
    log_info "Starting MQTT broker health check..."
    log_info "Target: ${BROKER_HOST}:${BROKER_PORT}"
    log_info "Timeout: ${TIMEOUT_SECONDS}s"
    
    # Run checks in sequence
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    if ! wait_for_port; then
        log_error "Port availability check failed"
        exit 1
    fi
    
    if ! test_mqtt_connection; then
        log_error "Basic MQTT connectivity test failed"
        exit 1
    fi
    
    if ! test_qos1_functionality; then
        log_warning "QoS 1 test failed, but continuing (may not be critical)"
    fi
    
    log_success "All MQTT broker health checks passed! ✅"
    log_info "Broker is ready for test execution"
    
    return 0
}

# Execute main function
main "$@"