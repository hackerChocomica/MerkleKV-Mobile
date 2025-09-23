import React from 'react';
import { Typography, Box } from '@mui/material';

const ConfigurationPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Configuration Management
      </Typography>
      <Typography variant="body1">
        Manage system and device configurations.
      </Typography>
    </Box>
  );
};

export default ConfigurationPage;