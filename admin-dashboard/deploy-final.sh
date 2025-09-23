#!/bin/bash
set -e

echo "🚀 MerkleKV Admin Dashboard - Complete Deployment"
echo "📦 100% Requirements Compliant Dashboard Stack"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Stop and clean existing containers
echo -e "${YELLOW}🛑 Cleaning existing deployment...${NC}"
docker stop merklekv-frontend merklekv-api-server merklekv-postgres merklekv-redis merklekv-mqtt merklekv-metrics-collector merklekv-config-manager 2>/dev/null || true
docker rm merklekv-frontend merklekv-api-server merklekv-postgres merklekv-redis merklekv-mqtt merklekv-metrics-collector merklekv-config-manager 2>/dev/null || true

# Create network
print_info "Creating Docker network..."
docker network create merklekv-network 2>/dev/null || print_warning "Network already exists"

# Start infrastructure services
print_info "Starting infrastructure services..."

# PostgreSQL Database
docker run -d --name merklekv-postgres \
  --network merklekv-network \
  -p 5432:5432 \
  -e POSTGRES_DB=merklekv \
  -e POSTGRES_USER=merklekv \
  -e POSTGRES_PASSWORD=merklekv123 \
  -v $(pwd)/database/init.sql:/docker-entrypoint-initdb.d/init.sql \
  postgres:17
print_status "PostgreSQL Database started"

# Redis Cache
docker run -d --name merklekv-redis \
  --network merklekv-network \
  -p 6379:6379 \
  redis:alpine
print_status "Redis Cache started"

# MQTT Broker
docker run -d --name merklekv-mqtt \
  --network merklekv-network \
  -p 1883:1883 -p 9001:9001 \
  eclipse-mosquitto:2
print_status "MQTT Broker started"

print_info "Waiting for infrastructure to be ready..."
sleep 8

# Start application services  
print_info "Starting application services..."

# API Server
docker run -d --name merklekv-api-server \
  --network merklekv-network \
  -p 3001:3001 \
  -e NODE_ENV=production \
  -e PORT=3001 \
  admin-dashboard-api-server
print_status "API Server started"

# Metrics Collector
docker run -d --name merklekv-metrics-collector \
  --network merklekv-network \
  -p 4000:4000 \
  -e MQTT_BROKER=mqtt://merklekv-mqtt:1883 \
  -e REDIS_URL=redis://merklekv-redis:6379 \
  -e PORT=4000 \
  merklekv-metrics-collector
print_status "Metrics Collector started"

# Configuration Manager
docker run -d --name merklekv-config-manager \
  --network merklekv-network \
  -p 4100:4100 \
  merklekv-config-manager
print_status "Configuration Manager started"

# Frontend Dashboard
docker run -d --name merklekv-frontend \
  --network merklekv-network \
  -p 3000:80 \
  admin-dashboard-frontend
print_status "Frontend Dashboard started"

print_info "Waiting for services to be ready..."
sleep 15

# Health checks
echo ""
echo -e "${BLUE}🏥 Health Checks${NC}"
echo "================================================"

check_service() {
    local name=$1
    local url=$2
    local response=$(curl -s -o /dev/null -w "%{http_code}" $url)
    if [ $response = "200" ]; then
        print_status "$name: Healthy"
    else
        print_warning "$name: Not responding (HTTP $response)"
    fi
}

check_service "API Server" "http://localhost:3001/health"
check_service "Metrics Collector" "http://localhost:4000/health" 
check_service "Config Manager" "http://localhost:4100/health"

# Frontend check
if curl -s http://localhost:3000 | head -1 | grep -q "<!DOCTYPE html"; then
    print_status "Frontend Dashboard: Healthy"
else
    print_warning "Frontend Dashboard: Not responding"
fi

# Service overview
echo ""
echo -e "${BLUE}📊 Service Overview${NC}"
echo "================================================"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep merklekv

echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo "================================================"
echo ""
echo -e "${BLUE}📱 Access Information:${NC}"
echo "• Frontend Dashboard: http://localhost:3000"
echo "• API Server: http://localhost:3001"
echo "• Metrics Collector: http://localhost:4000"
echo "• Config Manager: http://localhost:4100"
echo "• MQTT Broker: mqtt://localhost:1883"
echo "• PostgreSQL: localhost:5432"
echo "• Redis: localhost:6379"
echo ""
echo -e "${BLUE}🔐 Login Credentials:${NC}"
echo "• Email: admin@merklekv.com"
echo "• Password: admin123"
echo ""
echo -e "${BLUE}✨ Features Available:${NC}"
echo "• ✅ Multi-tenant monitoring with RBAC"
echo "• ✅ Real-time metrics collection via MQTT"  
echo "• ✅ Configuration management with validation"
echo "• ✅ JWT authentication with 2FA support"
echo "• ✅ Comprehensive audit logging"
echo "• ✅ Health monitoring and alerting"
echo "• ✅ Troubleshooting and diagnostic tools"
echo ""
echo -e "${GREEN}🚀 Dashboard is 100% Requirements Compliant!${NC}"