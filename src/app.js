const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const config = require('./utils/config');
const logger = require('./utils/logger');
const { authenticate } = require('./middleware/auth');
const { auditLog } = require('./middleware/audit');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');
const { globalLimiter, writeLimiter } = require('./middleware/rateLimit');

// Import routes
const reservationsRouter = require('./routes/reservations');
const leasesRouter = require('./routes/leases');
const healthRouter = require('./routes/health');

// Create Express app
const app = express();

// Trust proxy (for correct IP addresses behind load balancers)
app.set('trust proxy', true);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:'],
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// CORS configuration
app.use(cors({
  origin: config.cors?.allowedOrigins || false,
  credentials: true
}));

// Body parsing middleware
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Rate limiting
app.use(globalLimiter);

// Health check routes (no auth required)
app.use('/health', healthRouter);

// Audit logging (before auth to log failed auth attempts)
app.use(auditLog);

// Authentication middleware
app.use(authenticate);

// API routes
app.use('/scopes', writeLimiter, reservationsRouter);
app.use('/scopes', leasesRouter);

// 404 handler
app.use(notFoundHandler);

// Global error handler (must be last)
app.use(errorHandler);

// Graceful shutdown handler
const gracefulShutdown = (signal) => {
  logger.info(`${signal} received, starting graceful shutdown`);

  // Close server to stop accepting new connections
  if (app.server) {
    app.server.close(() => {
      logger.info('HTTP server closed');
      process.exit(0);
    });

    // Force shutdown after 30 seconds
    setTimeout(() => {
      logger.error('Forced shutdown after timeout');
      process.exit(1);
    }, 30000);
  } else {
    process.exit(0);
  }
};

// Register shutdown handlers
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception', {
    error: error.message,
    stack: error.stack
  });
  process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled promise rejection', {
    reason,
    promise
  });
});

module.exports = app;