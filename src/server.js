const https = require('https');
const http = require('http');
const fs = require('fs');
const app = require('./app');
const config = require('./utils/config');
const logger = require('./utils/logger');

// Start server
const startServer = () => {
  const port = config.service.port;
  const host = config.service.host;

  let server;

  // Create HTTPS server if TLS is enabled
  if (config.tls.enabled) {
    try {
      const options = {
        cert: fs.readFileSync(config.tls.certPath),
        key: fs.readFileSync(config.tls.keyPath)
      };

      // Add CA certificate if provided
      if (config.tls.trustedCaPath && fs.existsSync(config.tls.trustedCaPath)) {
        options.ca = fs.readFileSync(config.tls.trustedCaPath);
      }

      // mTLS configuration
      if (config.tls.requireClientCert) {
        options.requestCert = true;
        options.rejectUnauthorized = true;
        logger.info('mTLS client certificate authentication enabled');
      }

      server = https.createServer(options, app);
      logger.info('HTTPS server created with TLS enabled');
    } catch (error) {
      logger.error('Failed to create HTTPS server', {
        error: error.message,
        certPath: config.tls.certPath,
        keyPath: config.tls.keyPath
      });

      // Fall back to HTTP in development
      if (config.service.environment === 'development') {
        logger.warn('Falling back to HTTP server (development only)');
        server = http.createServer(app);
      } else {
        logger.error('TLS is required in production mode');
        process.exit(1);
      }
    }
  } else {
    // HTTP server (development only)
    if (config.service.environment === 'production') {
      logger.error('TLS must be enabled in production mode');
      process.exit(1);
    }

    server = http.createServer(app);
    logger.warn('HTTP server created (TLS disabled - development only)');
  }

  // Store server instance for graceful shutdown
  app.server = server;

  // Start listening
  server.listen(port, host, () => {
    const protocol = config.tls.enabled ? 'https' : 'http';
    logger.info(`DHCP REST Agent started`, {
      protocol,
      host,
      port,
      environment: config.service.environment,
      version: require('../package.json').version,
      pid: process.pid
    });

    logger.info(`Health check available at ${protocol}://${host}:${port}/health`);
    logger.info(`API endpoint: ${protocol}://${host}:${port}/scopes/:scopeId/reservations`);
  });

  // Handle server errors
  server.on('error', (error) => {
    if (error.code === 'EADDRINUSE') {
      logger.error(`Port ${port} is already in use`);
      process.exit(1);
    } else if (error.code === 'EACCES') {
      logger.error(`Port ${port} requires elevated privileges`);
      process.exit(1);
    } else {
      logger.error('Server error', { error: error.message });
      process.exit(1);
    }
  });

  return server;
};

// Start the server
if (require.main === module) {
  // Display startup banner
  logger.info('='.repeat(60));
  logger.info('  DHCP REST Agent');
  logger.info('  Windows DHCP Server REST API');
  logger.info(`  Version: ${require('../package.json').version}`);
  logger.info(`  Environment: ${config.service.environment}`);
  logger.info('='.repeat(60));

  startServer();
}

module.exports = { startServer };