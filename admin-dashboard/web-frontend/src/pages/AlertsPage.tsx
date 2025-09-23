import React from 'react';
import { Typography, Box } from '@mui/material';

const AlertsPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Alerts & Notifications
      </Typography>
      <Typography variant="body1">
        Manage system alerts and notification settings.
      </Typography>
    </Box>
  );
};

export default AlertsPage;