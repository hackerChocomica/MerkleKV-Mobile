import React from 'react';

// User and Authentication Types
export interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: UserRole;
  tenantId: string;
  permissions: Permission[];
  lastLogin: Date;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface LoginRequest {
  email: string;
  password: string;
  twoFactorCode?: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
}

export type UserRole = 'super-admin' | 'tenant-admin' | 'operator' | 'viewer';

export interface Permission {
  resource: string;
  actions: string[];
  conditions?: Record<string, any>;
}

export interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  accessToken?: string;
}

// Tenant Types
export interface Tenant {
  id: string;
  name: string;
  description?: string;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
  quotas: TenantQuotas;
  settings: TenantSettings;
}

export interface TenantQuotas {
  maxDevices: number;
  maxConnections: number;
  dataRetentionDays: number;
  apiRequestsPerMinute: number;
}

export interface TenantSettings {
  timezone: string;
  alertsEnabled: boolean;
  dataExportEnabled: boolean;
  customBranding?: {
    logo?: string;
    primaryColor?: string;
  };
}

// Device Types
export interface Device {
  id: string;
  name: string;
  tenantId: string;
  type: DeviceType;
  status: DeviceStatus;
  lastSeen?: Date;
  ipAddress?: string;
  userAgent?: string;
  version?: string;
  location?: DeviceLocation;
  metadata: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

export type DeviceType = 'mobile' | 'tablet' | 'desktop' | 'iot' | 'server';

export type DeviceStatus = 'online' | 'offline' | 'connecting' | 'error' | 'maintenance';

export interface DeviceLocation {
  country?: string;
  region?: string;
  city?: string;
  latitude?: number;
  longitude?: number;
}

// Metrics Types
export interface MetricDataPoint {
  timestamp: Date;
  value: number;
  tags?: Record<string, string>;
}

export interface MetricSeries {
  name: string;
  unit?: string;
  data: MetricDataPoint[];
}

export interface SystemMetrics {
  connectionCount: MetricSeries;
  throughput: MetricSeries;
  errorRate: MetricSeries;
  latency: MetricSeries;
  uptime: MetricSeries;
}

export interface DeviceMetrics {
  deviceId: string;
  batteryLevel?: number;
  connectionQuality: number;
  dataUsage: {
    sent: number;
    received: number;
  };
  errors: ErrorMetric[];
  performance: PerformanceMetric[];
}

export interface ErrorMetric {
  type: string;
  count: number;
  lastOccurred: Date;
  severity: 'low' | 'medium' | 'high' | 'critical';
}

export interface PerformanceMetric {
  operation: string;
  avgDuration: number;
  p95Duration: number;
  successRate: number;
}

// Alert Types
export interface Alert {
  id: string;
  tenantId?: string;
  title: string;
  description: string;
  severity: AlertSeverity;
  status: AlertStatus;
  source: string;
  sourceId?: string;
  createdAt: Date;
  updatedAt: Date;
  resolvedAt?: Date;
  resolvedBy?: string;
  tags: string[];
  metadata: Record<string, any>;
}

export type AlertSeverity = 'info' | 'warning' | 'error' | 'critical';
export type AlertStatus = 'open' | 'acknowledged' | 'resolved' | 'suppressed';

// Configuration Types
export interface Configuration {
  id: string;
  name: string;
  description?: string;
  tenantId?: string;
  version: string;
  schema: ConfigurationSchema;
  values: Record<string, any>;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
  createdBy: string;
  updatedBy: string;
  deploymentStatus?: DeploymentStatus;
}

export interface ConfigurationSchema {
  $schema: string;
  type: 'object';
  properties: Record<string, SchemaProperty>;
  required?: string[];
  additionalProperties?: boolean;
}

export interface SchemaProperty {
  type: string;
  description?: string;
  default?: any;
  enum?: any[];
  minimum?: number;
  maximum?: number;
  pattern?: string;
  items?: SchemaProperty;
  properties?: Record<string, SchemaProperty>;
}

export interface DeploymentStatus {
  status: 'pending' | 'deploying' | 'deployed' | 'failed' | 'rolled-back';
  startedAt?: Date;
  completedAt?: Date;
  progress?: number;
  error?: string;
  deployedDevices?: number;
  totalDevices?: number;
}

// Log Types
export interface LogEntry {
  id: string;
  timestamp: Date;
  level: LogLevel;
  message: string;
  source: string;
  sourceId?: string;
  tenantId?: string;
  deviceId?: string;
  userId?: string;
  metadata: Record<string, any>;
  traceId?: string;
  spanId?: string;
}

export type LogLevel = 'debug' | 'info' | 'warn' | 'error' | 'fatal';

// Audit Types
export interface AuditLog {
  id: string;
  timestamp: Date;
  userId: string;
  userName: string;
  action: string;
  resource: string;
  resourceId?: string;
  tenantId?: string;
  ipAddress?: string;
  userAgent?: string;
  details: Record<string, any>;
  result: 'success' | 'failure';
  error?: string;
}

// Dashboard Types
export interface DashboardStats {
  totalDevices: number;
  onlineDevices: number;
  totalTenants: number;
  activeTenants: number;
  errorRate: number;
  avgLatency: number;
  uptime: number;
  dataProcessed: number;
}

export interface DashboardTimeRange {
  start: Date;
  end: Date;
  preset?: '1h' | '6h' | '24h' | '7d' | '30d' | 'custom';
}

// API Response Types
export interface APIResponse<T> {
  data: T;
  success: boolean;
  message?: string;
  timestamp: Date;
}

export interface PaginatedResponse<T> extends APIResponse<T[]> {
  pagination: {
    page: number;
    limit: number;
    total: number;
    pages: number;
  };
}

export interface APIError {
  code: string;
  message: string;
  details?: Record<string, any>;
  timestamp: Date;
}

// WebSocket Types
export interface WebSocketMessage {
  type: string;
  payload: any;
  timestamp: Date;
  id?: string;
}

export interface RealTimeUpdate {
  type: 'device-status' | 'metrics' | 'alert' | 'configuration';
  resourceId: string;
  tenantId?: string;
  data: any;
}

// Filter and Search Types
export interface FilterCriteria {
  field: string;
  operator: 'eq' | 'ne' | 'gt' | 'gte' | 'lt' | 'lte' | 'in' | 'nin' | 'contains' | 'startsWith' | 'endsWith';
  value: any;
}

export interface SearchQuery {
  query?: string;
  filters?: FilterCriteria[];
  sort?: {
    field: string;
    direction: 'asc' | 'desc';
  };
  pagination?: {
    page: number;
    limit: number;
  };
}

// Component Props Types
export interface BaseComponentProps {
  className?: string;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}

export interface TableColumn<T> {
  key: keyof T;
  label: string;
  sortable?: boolean;
  filterable?: boolean;
  width?: number;
  render?: (value: any, row: T) => React.ReactNode;
}

export interface ChartConfig {
  type: 'line' | 'bar' | 'area' | 'pie' | 'donut';
  title?: string;
  xAxis?: {
    label?: string;
    type?: 'category' | 'number' | 'time';
  };
  yAxis?: {
    label?: string;
    type?: 'number';
    unit?: string;
  };
  colors?: string[];
  showLegend?: boolean;
  showGrid?: boolean;
}