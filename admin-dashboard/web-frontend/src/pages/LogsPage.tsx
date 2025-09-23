import React from 'react';
import { Typography, Box } from '@mui/material';

const LogsPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        System Logs
      </Typography>
      <Typography variant="body1">
        View and analyze system logs.
      </Typography>
    </Box>
  );
};

export default LogsPage;