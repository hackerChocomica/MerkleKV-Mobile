#!/bin/bash

# MQTT Broker Health Check Script
# Used by CI/CD and development environments

set -e

# Configuration
MQTT_HOST="${MQTT_BROKER_HOST:-localhost}"
MQTT_PORT="${MQTT_BROKER_PORT:-1883}"
TIMEOUT="${MQTT_HEALTH_TIMEOUT:-30}"

echo "Running MQTT broker health check..."
echo "Host: $MQTT_HOST"
echo "Port: $MQTT_PORT"
echo "Timeout: ${TIMEOUT}s"

# Function to check TCP connectivity
check_tcp_connectivity() {
    echo "Checking TCP connectivity to $MQTT_HOST:$MQTT_PORT..."
    if timeout 10 bash -c "</dev/tcp/$MQTT_HOST/$MQTT_PORT"; then
        echo "✅ TCP connection successful"
        return 0
    else
        echo "❌ TCP connection failed"
        return 1
    fi
}

# Function to check MQTT publish/subscribe functionality
check_mqtt_functionality() {
    echo "Testing MQTT publish/subscribe functionality..."
    
    local test_topic="health/check/$(date +%s)"
    local test_message="health_check_message"
    local received_message=""
    
    # Start subscriber in background
    timeout $TIMEOUT mosquitto_sub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$test_topic" -C 1 > /tmp/mqtt_health_sub.txt 2>&1 &
    local sub_pid=$!
    
    # Give subscriber time to connect
    sleep 2
    
    # Publish test message
    if mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$test_topic" -m "$test_message" 2>/dev/null; then
        echo "✅ MQTT publish successful"
    else
        echo "❌ MQTT publish failed"
        kill $sub_pid 2>/dev/null || true
        return 1
    fi
    
    # Wait for subscriber to receive message
    wait $sub_pid 2>/dev/null || true
    
    # Check if message was received
    if [ -f /tmp/mqtt_health_sub.txt ]; then
        received_message=$(cat /tmp/mqtt_health_sub.txt 2>/dev/null || echo "")
        if [ "$received_message" = "$test_message" ]; then
            echo "✅ MQTT subscribe successful"
            rm -f /tmp/mqtt_health_sub.txt
            return 0
        else
            echo "❌ MQTT subscribe failed - expected '$test_message', got '$received_message'"
            rm -f /tmp/mqtt_health_sub.txt
            return 1
        fi
    else
        echo "❌ MQTT subscribe failed - no output file"
        return 1
    fi
}

# Main health check
main() {
    local start_time=$(date +%s)
    
    if check_tcp_connectivity && check_mqtt_functionality; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "✅ MQTT broker health check passed in ${duration}s"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "❌ MQTT broker health check failed after ${duration}s"
        return 1
    fi
}

# Run health check
main "$@"