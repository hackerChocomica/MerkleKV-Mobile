import React, { createContext, useContext, useEffect, useState } from 'react';
import { User, LoginRequest, AuthTokens } from '../types';
import { authService } from '../services/api';

interface AuthContextType {
  user: User | null;
  tokens: AuthTokens | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (credentials: LoginRequest) => Promise<void>;
  logout: () => void;
  refreshToken: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export { AuthContext };

interface AuthProviderProps {
  children: React.ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [tokens, setTokens] = useState<AuthTokens | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const isAuthenticated = !!user && !!tokens;

  // Initialize auth state from localStorage
  useEffect(() => {
    const initializeAuth = async () => {
      try {
        const storedTokens = localStorage.getItem('authTokens');
        const storedUser = localStorage.getItem('user');

        if (storedTokens && storedUser) {
          const parsedTokens: AuthTokens = JSON.parse(storedTokens);
          const parsedUser: User = JSON.parse(storedUser);

          // Check if token is still valid
          const currentTime = Math.floor(Date.now() / 1000);
          if (parsedTokens.expiresAt > currentTime) {
            setTokens(parsedTokens);
            setUser(parsedUser);
            
            // Set the token for API requests
            authService.setAuthToken(parsedTokens.accessToken);
          } else {
            // Token expired, try to refresh
            try {
              await refreshTokenHelper(parsedTokens.refreshToken);
            } catch (error) {
              // Refresh failed, clear stored data
              clearAuthData();
            }
          }
        }
      } catch (error) {
        console.error('Error initializing auth:', error);
        clearAuthData();
      } finally {
        setIsLoading(false);
      }
    };

    initializeAuth();
  }, []);

  const login = async (credentials: LoginRequest) => {
    try {
      setIsLoading(true);
      const response = await authService.login(credentials);
      
      setUser(response.data.user);
      const tokens: AuthTokens = {
        accessToken: response.data.accessToken,
        refreshToken: response.data.refreshToken,
        expiresAt: Math.floor(Date.now() / 1000) + 3600, // 1 hour default
      };
      setTokens(tokens);
      
      // Store in localStorage
      localStorage.setItem('user', JSON.stringify(response.data.user));
      localStorage.setItem('authTokens', JSON.stringify(tokens));
      
      // Set token for API requests
      authService.setAuthToken(response.data.accessToken);
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    setUser(null);
    setTokens(null);
    clearAuthData();
    authService.setAuthToken(null);
  };

  const refreshTokenHelper = async (refreshTokenValue: string): Promise<void> => {
    const response = await authService.refreshToken({ refreshToken: refreshTokenValue });
    
    const newTokens: AuthTokens = {
      accessToken: response.data.accessToken,
      refreshToken: response.data.refreshToken,
      expiresAt: Math.floor(Date.now() / 1000) + 3600, // 1 hour default
    };
    setTokens(newTokens);
    
    localStorage.setItem('authTokens', JSON.stringify(newTokens));
    authService.setAuthToken(response.data.accessToken);
  };

  const refreshToken = async () => {
    if (!tokens?.refreshToken) {
      throw new Error('No refresh token available');
    }
    
    await refreshTokenHelper(tokens.refreshToken);
  };

  const clearAuthData = () => {
    localStorage.removeItem('user');
    localStorage.removeItem('authTokens');
  };

  const value: AuthContextType = {
    user,
    tokens,
    isAuthenticated,
    isLoading,
    login,
    logout,
    refreshToken,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};