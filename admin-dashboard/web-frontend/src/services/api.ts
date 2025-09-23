import axios, { AxiosInstance, AxiosResponse, AxiosError } from 'axios';
import { 
  User, 
  Tenant, 
  Device, 
  Configuration, 
  Alert, 
  LogEntry, 
  AuditLog,
  DashboardStats,
  SystemMetrics,
  DeviceMetrics,
  APIResponse,
  PaginatedResponse,
  APIError,
  SearchQuery,
  DashboardTimeRange,
  LoginRequest,
  AuthTokens
} from '../types';

// API Client Class
class APIClient {
  private client: AxiosInstance;
  private authToken: string | null = null;

  constructor(baseURL: string = 'http://localhost:3001') {
    this.client = axios.create({
      baseURL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.setupInterceptors();
  }

  setAuthToken(token: string | null) {
    this.authToken = token;
    if (token) {
      this.client.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    } else {
      delete this.client.defaults.headers.common['Authorization'];
    }
  }

  private setupInterceptors() {
    // Request interceptor
    this.client.interceptors.request.use(
      (config) => {
        if (this.authToken) {
          config.headers.Authorization = `Bearer ${this.authToken}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response: AxiosResponse) => response,
      async (error: AxiosError) => {
        if (error.response?.status === 401) {
          // Token expired, clear auth
          this.setAuthToken(null);
          localStorage.removeItem('accessToken');
          localStorage.removeItem('refreshToken');
          // Redirect to login
          window.location.href = '/login';
        }
        
        const apiError: APIError = {
          message: error.message,
          code: error.response?.status?.toString() || 'NETWORK_ERROR',
          details: error.response?.data as Record<string, any> | undefined,
          timestamp: new Date(),
        };
        
        return Promise.reject(apiError);
      }
    );
  }

  async get<T>(endpoint: string, params?: any): Promise<APIResponse<T>> {
    const response = await this.client.get(endpoint, { params });
    return response.data;
  }

  async post<T>(endpoint: string, data?: any): Promise<APIResponse<T>> {
    const response = await this.client.post(endpoint, data);
    return response.data;
  }

  async put<T>(endpoint: string, data?: any): Promise<APIResponse<T>> {
    const response = await this.client.put(endpoint, data);
    return response.data;
  }

  async patch<T>(endpoint: string, data?: any): Promise<APIResponse<T>> {
    const response = await this.client.patch(endpoint, data);
    return response.data;
  }

  async delete<T>(endpoint: string): Promise<APIResponse<T>> {
    const response = await this.client.delete(endpoint);
    return response.data;
  }
}

// Create global API client instance
const apiClient = new APIClient();

// Authentication Service
export const authService = {
  setAuthToken: (token: string | null) => {
    apiClient.setAuthToken(token);
  },

  async login(credentials: LoginRequest): Promise<APIResponse<{ user: User; accessToken: string; refreshToken: string; }>> {
    const response = await apiClient.post<{ user: User; accessToken: string; refreshToken: string; }>('/auth/login', credentials);
    return response;
  },

  async refreshToken(data: { refreshToken: string }): Promise<APIResponse<{ accessToken: string; refreshToken: string; }>> {
    const response = await apiClient.post<{ accessToken: string; refreshToken: string; }>('/auth/refresh', data);
    return response;
  },

  async logout(): Promise<APIResponse<void>> {
    try {
      await apiClient.post<void>('/auth/logout');
    } catch (error) {
      // Ignore logout errors, just clear local state
    }
    return { success: true, data: undefined, timestamp: new Date() };
  },

  async getCurrentUser(): Promise<APIResponse<User>> {
    const response = await apiClient.get<User>('/auth/me');
    return response;
  },

  async changePassword(oldPassword: string, newPassword: string): Promise<APIResponse<void>> {
    const response = await apiClient.post<void>('/auth/change-password', {
      oldPassword,
      newPassword,
    });
    return response;
  },

  async setupTwoFactor(): Promise<APIResponse<{ qrCode: string; secret: string; }>> {
    const response = await apiClient.post<{ qrCode: string; secret: string; }>('/auth/2fa/setup');
    return response;
  },

  async verifyTwoFactor(code: string): Promise<APIResponse<void>> {
    const response = await apiClient.post<void>('/auth/2fa/verify', { code });
    return response;
  },
};

// Dashboard Service
export const dashboardService = {
  async getStats(timeRange: DashboardTimeRange): Promise<APIResponse<DashboardStats>> {
    const params = { timeRange };
    const response = await apiClient.get<DashboardStats>('/dashboard/stats', params);
    return response;
  },

  async getMetrics(timeRange: DashboardTimeRange, tenantId?: string): Promise<APIResponse<SystemMetrics>> {
    const response = await apiClient.get<SystemMetrics>('/dashboard/metrics', {
      timeRange,
      tenantId,
    });
    return response;
  },

  async getHealthCheck(): Promise<APIResponse<{ status: string; services: Record<string, string>; }>> {
    const response = await apiClient.get<{ status: string; services: Record<string, string>; }>('/dashboard/health');
    return response;
  },
};

// Export the API client as default
export default apiClient;