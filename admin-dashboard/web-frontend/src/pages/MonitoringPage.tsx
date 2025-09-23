import React from 'react';
import { Typography, Box } from '@mui/material';

const MonitoringPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        System Monitoring
      </Typography>
      <Typography variant="body1">
        Real-time system metrics and performance monitoring.
      </Typography>
    </Box>
  );
};

export default MonitoringPage;