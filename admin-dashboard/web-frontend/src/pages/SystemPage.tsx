import React from 'react';
import { Typography, Box } from '@mui/material';

const SystemPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        System Administration
      </Typography>
      <Typography variant="body1">
        System-wide settings and administration tools.
      </Typography>
    </Box>
  );
};

export default SystemPage;