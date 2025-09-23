import React from 'react';
import { Typography, Box } from '@mui/material';

const DevicesPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Device Management
      </Typography>
      <Typography variant="body1">
        Monitor and manage connected devices.
      </Typography>
    </Box>
  );
};

export default DevicesPage;