import React from 'react';
import { Typography, Box } from '@mui/material';

const AuditPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Audit Logs
      </Typography>
      <Typography variant="body1">
        Security audit logs and compliance tracking.
      </Typography>
    </Box>
  );
};

export default AuditPage;