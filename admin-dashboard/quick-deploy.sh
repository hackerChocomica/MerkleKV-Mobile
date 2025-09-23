#!/bin/bash
set -e

echo "🚀 Quick Deploy MerkleKV Admin Dashboard (Optimized)"

# Stop and remove old containers
echo "🛑 Stopping existing containers..."
docker stop merklekv-frontend merklekv-api-server merklekv-postgres merklekv-redis 2>/dev/null || true
docker rm merklekv-frontend merklekv-api-server merklekv-postgres merklekv-redis 2>/dev/null || true

# Create network if not exists
docker network create merklekv-network 2>/dev/null || true

echo "📦 Starting core services (using existing images)..."

# Start PostgreSQL
docker run -d --name merklekv-postgres \
  --network merklekv-network \
  -p 5432:5432 \
  -e POSTGRES_DB=merklekv \
  -e POSTGRES_USER=merklekv \
  -e POSTGRES_PASSWORD=merklekv123 \
  -v $(pwd)/database/init.sql:/docker-entrypoint-initdb.d/init.sql \
  postgres:17

# Start Redis
docker run -d --name merklekv-redis \
  --network merklekv-network \
  -p 6379:6379 \
  redis:alpine

# Start API Server (existing image)
docker run -d --name merklekv-api-server \
  --network merklekv-network \
  -p 3001:3001 \
  -e NODE_ENV=production \
  -e PORT=3001 \
  admin-dashboard-api-server

# Start Frontend (existing image)
docker run -d --name merklekv-frontend \
  --network merklekv-network \
  -p 3000:80 \
  admin-dashboard-frontend

echo "⏱️ Waiting for services to be ready..."
sleep 10

echo "🏥 Health checks..."
curl -s http://localhost:3001/health | jq . || echo "API not ready yet"
curl -s http://localhost:3000 | head -1 | grep -q "<!DOCTYPE html" && echo "✅ Frontend ready" || echo "❌ Frontend not ready"

echo "✅ Quick deployment complete!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔌 API: http://localhost:3001"
echo "🔐 Login: admin@merklekv.com / admin123"