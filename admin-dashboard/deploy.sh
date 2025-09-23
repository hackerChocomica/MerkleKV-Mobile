#!/bin/bash

set -e

echo "🚀 Building MerkleKV Admin Dashboard Stack..."

# Change to admin dashboard directory
cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose > /dev/null 2>&1; then
    print_error "Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

print_status "Stopping any existing containers..."
docker-compose down --remove-orphans || true

print_status "Building Docker images..."
docker-compose build --no-cache

print_status "Starting services..."
docker-compose up -d

print_status "Waiting for services to be ready..."
sleep 10

# Health checks
print_status "Performing health checks..."

# Check API server
API_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health || echo "000")
if [ "$API_HEALTH" = "200" ]; then
    print_success "✅ API Server is healthy"
else
    print_warning "⚠️  API Server health check failed (HTTP $API_HEALTH)"
fi

# Check frontend
FRONTEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health || echo "000")
if [ "$FRONTEND_HEALTH" = "200" ]; then
    print_success "✅ Frontend is healthy"
else
    print_warning "⚠️  Frontend health check failed (HTTP $FRONTEND_HEALTH)"
fi

# Check PostgreSQL
if docker-compose exec -T database pg_isready -U merklekv > /dev/null 2>&1; then
    print_success "✅ PostgreSQL is healthy"
else
    print_warning "⚠️  PostgreSQL health check failed"
fi

# Check Redis
if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
    print_success "✅ Redis is healthy"
else
    print_warning "⚠️  Redis health check failed"
fi

echo ""
print_success "🎉 MerkleKV Admin Dashboard Stack is running!"
echo ""
echo "📱 Access URLs:"
echo "   Frontend:  http://localhost:3000"
echo "   API:       http://localhost:3001"
echo "   Database:  localhost:5432"
echo "   Redis:     localhost:6379"
echo "   MQTT:      localhost:1883"
echo ""
echo "🔐 Login Credentials:"
echo "   Email:     admin@merklekv.com"
echo "   Password:  admin123"
echo ""
echo "📊 Management Commands:"
echo "   View logs:    docker-compose logs -f"
echo "   Stop stack:   docker-compose down"
echo "   Restart:      docker-compose restart"
echo ""

# Show container status
print_status "Container Status:"
docker-compose ps