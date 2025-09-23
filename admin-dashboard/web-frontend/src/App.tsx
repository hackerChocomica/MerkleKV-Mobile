import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import { CssBaseline, Box } from '@mui/material';
import { QueryClient, QueryClientProvider } from 'react-query';
import { SnackbarProvider } from 'notistack';

// Layout Components
import AppBar from './components/AppBar';
import Sidebar from './components/Sidebar';
import LoadingSpinner from './components/LoadingSpinner';

// Pages
import DashboardPage from './pages/DashboardPage';
import TenantsPage from './pages/TenantsPage';
import DevicesPage from './pages/DevicesPage';
import MonitoringPage from './pages/MonitoringPage';
import AlertsPage from './pages/AlertsPage';
import ConfigurationPage from './pages/ConfigurationPage';
import LogsPage from './pages/LogsPage';
import AuditPage from './pages/AuditPage';
import UsersPage from './pages/UsersPage';
import SystemPage from './pages/SystemPage';
import LoginPage from './pages/LoginPage';

// Hooks and Context
import { useAuth } from './hooks/useAuth';
import { AuthProvider } from './contexts/AuthContext';

// Create Material-UI theme
const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
    background: {
      default: '#f5f5f5',
    },
  },
  typography: {
    fontFamily: '"Roboto", "Helvetica", "Arial", sans-serif',
  },
});

// Create React Query client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 3,
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
    },
  },
});

// Protected Route Component
const ProtectedRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return <LoadingSpinner />;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
};

// Main Layout Component
const MainLayout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [sidebarOpen, setSidebarOpen] = React.useState(true);

  const handleSidebarToggle = () => {
    setSidebarOpen(!sidebarOpen);
  };

  return (
    <Box sx={{ display: 'flex', height: '100vh' }}>
      <AppBar onSidebarToggle={handleSidebarToggle} />
      <Sidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          p: 3,
          marginTop: '64px', // Height of AppBar
          marginLeft: sidebarOpen ? '240px' : '0px', // Width of Sidebar
          transition: 'margin-left 0.3s ease',
        }}
      >
        {children}
      </Box>
    </Box>
  );
};

// Main App Component
const App: React.FC = () => {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <SnackbarProvider maxSnack={3} anchorOrigin={{ vertical: 'top', horizontal: 'right' }}>
          <AuthProvider>
            <Router>
              <Routes>
                {/* Public Routes */}
                <Route path="/login" element={<LoginPage />} />
                
                {/* Protected Routes */}
                <Route path="/" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <Navigate to="/dashboard" replace />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                <Route path="/dashboard" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <DashboardPage />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                <Route path="/tenants" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <TenantsPage />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                <Route path="/devices" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <DevicesPage />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                <Route path="/monitoring" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <MonitoringPage />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                <Route path="/alerts" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <AlertsPage />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                <Route path="/configuration" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <ConfigurationPage />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                <Route path="/logs" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <LogsPage />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                <Route path="/audit" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <AuditPage />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                <Route path="/users" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <UsersPage />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                <Route path="/system" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <SystemPage />
                    </MainLayout>
                  </ProtectedRoute>
                } />
                
                {/* Catch all route */}
                <Route path="*" element={
                  <ProtectedRoute>
                    <MainLayout>
                      <Navigate to="/dashboard" replace />
                    </MainLayout>
                  </ProtectedRoute>
                } />
              </Routes>
            </Router>
          </AuthProvider>
        </SnackbarProvider>
      </ThemeProvider>
    </QueryClientProvider>
  );
};

export default App;