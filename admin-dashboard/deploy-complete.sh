#!/bin/bash

# Enhanced deployment script for complete MerkleKV Admin Dashboard
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Deploying Complete MerkleKV Admin Dashboard Stack...${NC}"

# Function to check if a service is healthy
check_service_health() {
    local service_name=$1
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f docker-compose-complete.yml ps | grep $service_name | grep -q "healthy"; then
            echo -e "${GREEN}✅ $service_name is healthy${NC}"
            return 0
        fi
        echo -e "${YELLOW}⏳ Waiting for $service_name to be healthy (attempt $attempt/$max_attempts)...${NC}"
        sleep 5
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}❌ $service_name failed to become healthy${NC}"
    return 1
}

# Stop any existing containers
echo -e "${YELLOW}[INFO] Stopping existing containers...${NC}"
docker-compose -f docker-compose-complete.yml down || true

# Build all images
echo -e "${YELLOW}[INFO] Building all Docker images...${NC}"
docker-compose -f docker-compose-complete.yml build --no-cache

# Start services in order
echo -e "${YELLOW}[INFO] Starting infrastructure services...${NC}"
docker-compose -f docker-compose-complete.yml up -d database redis mqtt-broker

# Wait for infrastructure to be ready
echo -e "${YELLOW}[INFO] Waiting for infrastructure services...${NC}"
sleep 10

# Start application services
echo -e "${YELLOW}[INFO] Starting application services...${NC}"
docker-compose -f docker-compose-complete.yml up -d api-server metrics-collector config-manager troubleshooting-tools

# Wait for backend services
echo -e "${YELLOW}[INFO] Waiting for backend services...${NC}"
sleep 15

# Start frontend
echo -e "${YELLOW}[INFO] Starting frontend...${NC}"
docker-compose -f docker-compose-complete.yml up -d frontend

# Health checks
echo -e "${BLUE}🔍 Performing health checks...${NC}"

services=(
    "merklekv-postgres"
    "merklekv-redis" 
    "merklekv-mqtt"
    "merklekv-api-server"
    "merklekv-metrics-collector"
    "merklekv-config-manager"
    "merklekv-troubleshooting-tools"
    "merklekv-admin-frontend"
)

all_healthy=true
for service in "${services[@]}"; do
    if ! check_service_health $service; then
        all_healthy=false
    fi
done

# Display service status
echo -e "${BLUE}📊 Service Status:${NC}"
docker-compose -f docker-compose-complete.yml ps

# Test endpoints
echo -e "${BLUE}🧪 Testing API endpoints...${NC}"

# Test API health
if curl -s http://localhost:3001/health > /dev/null; then
    echo -e "${GREEN}✅ API Server: http://localhost:3001/health${NC}"
else
    echo -e "${RED}❌ API Server health check failed${NC}"
    all_healthy=false
fi

# Test metrics collector
if curl -s http://localhost:4000/health > /dev/null; then
    echo -e "${GREEN}✅ Metrics Collector: http://localhost:4000/health${NC}"
else
    echo -e "${RED}❌ Metrics Collector health check failed${NC}"
    all_healthy=false
fi

# Test config manager
if curl -s http://localhost:4100/health > /dev/null; then
    echo -e "${GREEN}✅ Config Manager: http://localhost:4100/health${NC}"
else
    echo -e "${RED}❌ Config Manager health check failed${NC}"
    all_healthy=false
fi

# Test troubleshooting tools
if curl -s http://localhost:4200/health > /dev/null; then
    echo -e "${GREEN}✅ Troubleshooting Tools: http://localhost:4200/health${NC}"
else
    echo -e "${RED}❌ Troubleshooting Tools health check failed${NC}"
    all_healthy=false
fi

# Test frontend
if curl -s http://localhost:3000 > /dev/null; then
    echo -e "${GREEN}✅ Frontend: http://localhost:3000${NC}"
else
    echo -e "${RED}❌ Frontend health check failed${NC}"
    all_healthy=false
fi

# Display access information
echo -e "${BLUE}🌐 Access Information:${NC}"
echo -e "${GREEN}Frontend Dashboard: http://localhost:3000${NC}"
echo -e "${GREEN}API Server: http://localhost:3001${NC}"
echo -e "${GREEN}Metrics Collector: http://localhost:4000${NC}"
echo -e "${GREEN}Config Manager: http://localhost:4100${NC}"
echo -e "${GREEN}Troubleshooting Tools: http://localhost:4200${NC}"
echo -e "${GREEN}WebSocket Logs: ws://localhost:4201${NC}"

echo -e "${BLUE}🔐 Login Credentials:${NC}"
echo -e "${GREEN}Email: admin@merklekv.com${NC}"
echo -e "${GREEN}Password: admin123${NC}"

echo -e "${BLUE}📋 Features Available:${NC}"
echo -e "${GREEN}✅ Multi-tenant monitoring with RBAC${NC}"
echo -e "${GREEN}✅ Real-time MQTT metrics collection${NC}"
echo -e "${GREEN}✅ Configuration management with validation${NC}"
echo -e "${GREEN}✅ Log aggregation and troubleshooting tools${NC}"
echo -e "${GREEN}✅ Enhanced security with audit logging${NC}"
echo -e "${GREEN}✅ 2FA support and password policies${NC}"
echo -e "${GREEN}✅ Rate limiting and session management${NC}"

if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}🎉 Deployment successful! All services are running and healthy.${NC}"
    echo -e "${GREEN}🚀 MerkleKV Admin Dashboard is ready for use!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some services are not healthy. Check logs with:${NC}"
    echo -e "${YELLOW}docker-compose -f docker-compose-complete.yml logs [service-name]${NC}"
    exit 1
fi