# MerkleKV Admin Dashboard - Docker Deployment

## Quick Start

### Option 1: Docker Compose (Recommended)

```bash
# Navigate to admin dashboard directory
cd /root/MerkleKV-Mobile/admin-dashboard

# Run the deployment script
./deploy.sh
```

### Option 2: Manual Docker Compose

```bash
# Build and start all services
docker-compose up -d --build

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Option 3: Kurtosis (Advanced)

```bash
# Install Kurtosis (if not already installed)
curl -fsSL https://get.kurtosis.com | bash

# Run the Kurtosis package
kurtosis run github.com/ai-decenter/MerkleKV-Mobile/admin-dashboard
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| Frontend | 3000 | React TypeScript Admin Dashboard |
| API Server | 3001 | Node.js Express API |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache & Sessions |
| MQTT Broker | 1883 | IoT Communication |

## Access Information

- **Frontend URL**: http://localhost:3000
- **API URL**: http://localhost:3001
- **Login Credentials**:
  - Email: `admin@merklekv.com`
  - Password: `admin123`

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React Admin   │───▶│   Node.js API   │───▶│   PostgreSQL    │
│   Dashboard     │    │     Server      │    │    Database     │
│    (Port 3000)  │    │   (Port 3001)   │    │   (Port 5432)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │      Redis      │
                       │     Cache       │
                       │   (Port 6379)   │
                       └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │  MQTT Broker    │
                       │   (Eclipse      │
                       │   Mosquitto)    │
                       │   (Port 1883)   │
                       └─────────────────┘
```

## Features

### Frontend (React TypeScript)
- ✅ Material-UI design system
- ✅ Responsive layout with sidebar navigation
- ✅ Authentication with JWT tokens
- ✅ Real-time dashboard with metrics
- ✅ Multi-tenant support
- ✅ Role-based access control (RBAC)
- ✅ Device management interface
- ✅ System monitoring and alerts
- ✅ Configuration management
- ✅ Audit logging viewer

### Backend API
- ✅ RESTful API with Express.js
- ✅ JWT authentication and refresh tokens
- ✅ PostgreSQL database integration
- ✅ Redis caching
- ✅ CORS enabled
- ✅ Health check endpoints
- ✅ Mock data for development

### Infrastructure
- ✅ Multi-stage Docker builds
- ✅ Production-ready Nginx configuration
- ✅ Database migrations
- ✅ Health checks for all services
- ✅ Persistent volumes for data
- ✅ Network isolation

## Development

### Local Development Setup

```bash
# Frontend development
cd web-frontend
yarn install
yarn dev

# API development
cd api-server
npm install
npm run dev
```

### Environment Variables

Create `.env` files for each service:

**Frontend (.env):**
```
REACT_APP_API_URL=http://localhost:3001/api
```

**API Server (.env):**
```
NODE_ENV=development
PORT=3001
JWT_SECRET=your-secret-key
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=merklekv
POSTGRES_USER=merklekv
POSTGRES_PASSWORD=your-password
REDIS_HOST=localhost
REDIS_PORT=6379
```

## Monitoring

### Health Checks

```bash
# Frontend health
curl http://localhost:3000/health

# API health
curl http://localhost:3001/health

# Database health
docker-compose exec database pg_isready -U merklekv

# Redis health
docker-compose exec redis redis-cli ping
```

### Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f frontend
docker-compose logs -f api-server
docker-compose logs -f database
```

## Troubleshooting

### Common Issues

1. **Port conflicts**: Change ports in `docker-compose.yml`
2. **Database connection**: Check PostgreSQL container logs
3. **Build failures**: Run `docker-compose build --no-cache`
4. **Permission issues**: Check file permissions for volumes

### Reset Everything

```bash
# Stop and remove all containers, networks, and volumes
docker-compose down -v --remove-orphans

# Remove images
docker-compose build --no-cache

# Start fresh
./deploy.sh
```

## Production Deployment

### Security Considerations

1. Change default passwords
2. Use environment variables for secrets
3. Enable HTTPS with SSL certificates
4. Configure firewall rules
5. Regular security updates

### Scaling

- Use Docker Swarm or Kubernetes for horizontal scaling
- Add load balancer for multiple frontend instances
- Configure PostgreSQL for high availability
- Use Redis Cluster for cache scaling

## Support

For issues and questions:
- Check logs: `docker-compose logs -f`
- Restart services: `docker-compose restart`
- Full reset: `docker-compose down -v && ./deploy.sh`