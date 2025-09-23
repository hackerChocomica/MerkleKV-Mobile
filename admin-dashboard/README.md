# MerkleKV Admin Dashboard

> **Comprehensive administrative dashboard for monitoring, managing, and debugging MerkleKV Mobile deployments**

## 🎯 Overview

The MerkleKV Admin Dashboard is a separate repository providing operational visibility and management capabilities for MerkleKV Mobile deployments. It offers real-time monitoring, configuration management, and troubleshooting tools while maintaining clear architectural separation from the core mobile library.

## 📋 Requirements & Specifications

### Functional Requirements

#### 1. User Personas
- **System Administrator**: Full access to all tenants, system configuration, and monitoring
- **Tenant Administrator**: Access to specific tenant data, limited configuration management
- **Operations Engineer**: Read-only monitoring, troubleshooting access
- **Support Agent**: Limited diagnostic access for customer support

#### 2. Core Capabilities

##### Real-time Monitoring
- **Connection Status**: Live view of MQTT connections, device states
- **Operation Throughput**: Message rates, data sync performance
- **Error Rates**: Connection failures, sync errors, retry statistics
- **System Health**: Broker status, API availability, resource utilization

##### Multi-tenant Support
- **Tenant Isolation**: Strict data separation between tenants
- **Aggregate Views**: Cross-tenant analytics for system administrators
- **Per-tenant Dashboards**: Isolated monitoring for tenant administrators
- **Resource Quotas**: Monitoring and enforcement of tenant limits

##### Configuration Management
- **Centralized Configuration**: Single source of truth for deployment configs
- **Validation**: Schema validation and compatibility checks
- **Safe Deployment**: Staged rollouts, rollback capabilities
- **Version Control**: Configuration history and change tracking

##### Troubleshooting Tools
- **Log Aggregation**: Centralized logging from mobile devices and infrastructure
- **Trace Analysis**: End-to-end request tracing and performance analysis
- **Diagnostic Tools**: Connection testing, data verification utilities
- **Alert Management**: Configurable alerts and notification systems

## 🏗️ Architecture Design

### Repository Structure
```
MerkleKV-Admin-Dashboard/
├── web-frontend/          # React TypeScript web interface
│   ├── src/
│   │   ├── components/    # Reusable UI components
│   │   ├── pages/         # Dashboard pages
│   │   ├── services/      # API clients and business logic
│   │   ├── hooks/         # Custom React hooks
│   │   └── types/         # TypeScript type definitions
│   ├── public/
│   └── package.json
├── api-server/            # Node.js/Express REST API
│   ├── src/
│   │   ├── routes/        # API route handlers
│   │   ├── middleware/    # Authentication, validation
│   │   ├── services/      # Business logic
│   │   └── models/        # Data models
│   ├── config/
│   └── package.json
├── metrics-collector/     # MQTT metrics collection service
│   ├── src/
│   │   ├── collectors/    # Metric collection logic
│   │   ├── processors/    # Data processing pipelines
│   │   └── storage/       # Time-series data storage
│   └── config/
├── config-manager/        # Configuration management service
│   ├── src/
│   │   ├── validators/    # Configuration validation
│   │   ├── deployers/     # Deployment orchestration
│   │   └── versioning/    # Version control logic
│   └── schemas/
├── docs/                  # Documentation
│   ├── api/              # API documentation
│   ├── deployment/       # Deployment guides
│   └── user-guide/       # User documentation
├── docker-compose.yml     # Local development environment
├── k8s/                  # Kubernetes deployment manifests
└── README.md
```

### Technology Stack

#### Web Frontend
- **Framework**: React 18+ with TypeScript
- **UI Library**: Material-UI (MUI) for consistent design
- **State Management**: React Query for server state, Zustand for client state
- **Charts**: Recharts for data visualization
- **Real-time**: Socket.io for live updates
- **Routing**: React Router v6

#### API Server
- **Runtime**: Node.js with Express.js
- **Language**: TypeScript
- **Database**: PostgreSQL for structured data, InfluxDB for time-series
- **Authentication**: JWT with refresh tokens
- **Validation**: Joi/Yup for request validation
- **Real-time**: Socket.io for WebSocket connections

#### Metrics Collector
- **MQTT Client**: Eclipse Paho or Mosquitto client
- **Data Processing**: Stream processing with event handlers
- **Storage**: InfluxDB for time-series metrics
- **Queuing**: Redis for buffering and job queues

#### Configuration Manager
- **Storage**: Git-based configuration storage
- **Validation**: JSON Schema validation
- **Deployment**: Kubernetes operators or direct API calls
- **Versioning**: Semantic versioning with rollback support

## 🔌 Integration Patterns

### MQTT Metrics Collection
```typescript
interface MetricsCollectionConfig {
  mqttBroker: {
    host: string;
    port: number;
    username?: string;
    password?: string;
    tls: boolean;
  };
  topics: {
    deviceMetrics: string;     // "+/metrics/device"
    connectionEvents: string;  // "+/events/connection"
    operationStats: string;    // "+/stats/operations"
  };
  retention: {
    realTime: string;         // "1h"
    hourly: string;          // "7d"
    daily: string;           // "30d"
  };
}
```

### REST API Integration
```typescript
// Mobile Library → Dashboard API
interface DashboardAPIClient {
  // Device registration and status
  registerDevice(deviceInfo: DeviceInfo): Promise<void>;
  updateDeviceStatus(deviceId: string, status: DeviceStatus): Promise<void>;
  
  // Configuration retrieval
  getConfiguration(tenantId: string, deviceId: string): Promise<Configuration>;
  
  // Metrics reporting
  reportMetrics(deviceId: string, metrics: DeviceMetrics): Promise<void>;
  
  // Health checks
  healthCheck(): Promise<HealthStatus>;
}
```

### Authentication & Authorization
```typescript
interface AuthConfig {
  jwt: {
    secret: string;
    accessTokenExpiry: string;   // "15m"
    refreshTokenExpiry: string;  // "7d"
  };
  rbac: {
    roles: RoleDefinition[];
    permissions: PermissionSet[];
  };
  audit: {
    enabled: boolean;
    retention: string;          // "90d"
  };
}
```

## 🔒 Security Requirements

### Access Control
- **Role-Based Access Control (RBAC)**:
  - `super-admin`: Full system access
  - `tenant-admin`: Tenant-specific management
  - `operator`: Read/write operational access
  - `viewer`: Read-only monitoring access

### Authentication
- **Multi-factor Authentication (2FA)** for administrative accounts
- **Single Sign-On (SSO)** integration support (SAML, OAuth)
- **Session Management** with secure token handling
- **Password Policies** with complexity requirements

### Audit Logging
- **Comprehensive Logging** of all administrative actions
- **Immutable Audit Trail** with cryptographic integrity
- **Log Retention** policies for compliance
- **Real-time Alerting** for suspicious activities

### Data Protection
- **Encryption at Rest** for sensitive configuration data
- **Encryption in Transit** for all API communications
- **Data Anonymization** for cross-tenant analytics
- **Secure Credential Storage** with rotation capabilities

## 📊 Observability & Monitoring

### Dashboard Usage Metrics
```typescript
interface DashboardMetrics {
  // Usage tracking
  admin_dashboard_sessions: Counter;
  configuration_changes_total: Counter;
  api_requests_total: Counter;
  
  // System monitoring
  monitored_devices_count: Gauge;
  metrics_collection_rate: Gauge;
  active_connections: Gauge;
  
  // Performance
  dashboard_response_time: Histogram;
  monitoring_data_freshness: Gauge;
  api_latency: Histogram;
  
  // Security
  admin_access_attempts: Counter;
  unauthorized_access_blocked: Counter;
  authentication_failures: Counter;
}
```

### Health Endpoints
- `/health` - Basic health check
- `/health/detailed` - Comprehensive system status
- `/metrics` - Prometheus-compatible metrics
- `/status` - Service dependencies status

## 🚀 Deployment Patterns

### Local Development
```bash
# Start all services with Docker Compose
docker-compose up -d

# Access dashboard at http://localhost:3000
# API server at http://localhost:8080
# Metrics collector at http://localhost:8081
```

### Production Deployment
```yaml
# Kubernetes deployment example
apiVersion: apps/v1
kind: Deployment
metadata:
  name: merklekv-admin-dashboard
spec:
  replicas: 3
  selector:
    matchLabels:
      app: merklekv-admin-dashboard
  template:
    metadata:
      labels:
        app: merklekv-admin-dashboard
    spec:
      containers:
      - name: web-frontend
        image: merklekv/admin-dashboard-frontend:latest
        ports:
        - containerPort: 3000
      - name: api-server
        image: merklekv/admin-dashboard-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: dashboard-secrets
              key: database-url
```

### Scaling Considerations
- **Horizontal Scaling**: Stateless design for easy scaling
- **Load Balancing**: Support for multiple dashboard instances
- **Database Scaling**: Read replicas for monitoring data
- **Cache Layer**: Redis for frequently accessed data

## 🧪 Testing Strategy

### Requirements Validation
- **Stakeholder Review**: Regular feedback sessions with operations teams
- **User Acceptance Testing**: Testing with actual operators
- **Usability Testing**: Interface design validation

### Technical Testing
- **Unit Tests**: Individual component testing
- **Integration Tests**: API and service integration
- **End-to-End Tests**: Full workflow testing
- **Performance Tests**: Load testing for scale validation

### Security Testing
- **Penetration Testing**: Security vulnerability assessment
- **Access Control Testing**: RBAC validation
- **Audit Trail Testing**: Logging completeness verification

## 📈 Success Metrics

### Operational Efficiency
- **Mean Time to Detection (MTTD)**: < 5 minutes for critical issues
- **Mean Time to Resolution (MTTR)**: < 30 minutes for common issues
- **Dashboard Adoption Rate**: > 90% of operations team usage
- **Configuration Deployment Success Rate**: > 99.5%

### User Experience
- **Dashboard Load Time**: < 2 seconds initial load
- **Real-time Data Freshness**: < 30 seconds delay
- **User Satisfaction Score**: > 4.5/5.0
- **Support Ticket Reduction**: 40% reduction in operational tickets

### System Performance
- **High-Volume Support**: 10,000+ concurrent monitored devices
- **Data Retention**: 30 days real-time, 1 year aggregated
- **Uptime**: 99.9% availability SLA
- **Scalability**: Linear scaling to 100,000+ devices

## 🔄 API Specifications

### Authentication Endpoints
```typescript
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
GET  /api/auth/me
```

### Dashboard Endpoints
```typescript
GET  /api/dashboard/overview
GET  /api/dashboard/metrics
GET  /api/dashboard/health
```

### Tenant Management
```typescript
GET    /api/tenants
POST   /api/tenants
GET    /api/tenants/:id
PUT    /api/tenants/:id
DELETE /api/tenants/:id
```

### Device Management
```typescript
GET  /api/devices
GET  /api/devices/:id
PUT  /api/devices/:id/status
GET  /api/devices/:id/metrics
GET  /api/devices/:id/logs
```

### Configuration Management
```typescript
GET  /api/configs
POST /api/configs
GET  /api/configs/:id
PUT  /api/configs/:id
POST /api/configs/:id/deploy
POST /api/configs/:id/rollback
```

## 🚀 Quick Start Guide

### Prerequisites
- Node.js 18+
- Docker & Docker Compose
- PostgreSQL 14+
- Redis 6+

### Installation
```bash
# Clone the repository
git clone https://github.com/your-org/MerkleKV-Admin-Dashboard.git
cd MerkleKV-Admin-Dashboard

# Install dependencies
npm run install:all

# Setup environment
cp .env.example .env
# Edit .env with your configuration

# Start development environment
npm run dev

# Run tests
npm run test:all

# Build for production
npm run build:all
```

### Configuration
```yaml
# config/dashboard.yml
dashboard:
  port: 3000
  api_url: "http://localhost:8080"
  
api:
  port: 8080
  database_url: "postgresql://user:pass@localhost:5432/dashboard"
  jwt_secret: "your-secret-key"
  
metrics:
  mqtt_broker: "mqtt://localhost:1883"
  retention_days: 30
  
security:
  enable_2fa: true
  session_timeout: "24h"
  audit_retention: "90d"
```

## 📚 Documentation Links

- [API Documentation](./docs/api/README.md)
- [Deployment Guide](./docs/deployment/README.md)
- [User Guide](./docs/user-guide/README.md)
- [Security Guidelines](./docs/security/README.md)
- [Troubleshooting](./docs/troubleshooting/README.md)

---

## 🎯 Acceptance Criteria Validation

✅ **All operational needs addressed**: Comprehensive monitoring, configuration, and troubleshooting capabilities

✅ **Tenant isolation maintained**: Strict RBAC and data separation by tenant

✅ **Configuration validation and safe deployment**: Schema validation, staged rollouts, rollback support

✅ **Diagnostic information available**: Log aggregation, trace analysis, real-time monitoring

✅ **Access controls enforced**: Multi-factor auth, RBAC, audit logging

✅ **High-volume deployment support**: Designed for 10,000+ devices with linear scaling

This specification provides a complete foundation for implementing the MerkleKV Admin Dashboard as a separate repository while maintaining clean architectural boundaries and comprehensive operational capabilities.