import React from 'react';
import { Typography, Box } from '@mui/material';

const UsersPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        User Management
      </Typography>
      <Typography variant="body1">
        Manage user accounts and permissions.
      </Typography>
    </Box>
  );
};

export default UsersPage;