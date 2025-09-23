import React from 'react';
import { Typography, Box } from '@mui/material';

const TenantsPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Tenants Management
      </Typography>
      <Typography variant="body1">
        Manage tenant accounts and configurations.
      </Typography>
    </Box>
  );
};

export default TenantsPage;