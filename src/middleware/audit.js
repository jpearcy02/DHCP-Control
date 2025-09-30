const logger = require('../utils/logger');
const config = require('../utils/config');

/**
 * Audit logging middleware
 * Logs all API requests and responses for compliance
 */
const auditLog = (req, res, next) => {
  if (!config.audit.enabled) {
    return next();
  }

  // Capture request start time
  const startTime = Date.now();

  // Store original res.json for interception
  const originalJson = res.json.bind(res);

  // Override res.json to capture response
  res.json = function (body) {
    const duration = Date.now() - startTime;

    // Build audit entry
    const auditEntry = {
      timestamp: new Date().toISOString(),
      user: req.user ? req.user.id : 'anonymous',
      authMethod: req.user ? req.user.method : 'none',
      ip: req.ip || req.connection.remoteAddress,
      method: req.method,
      path: req.path,
      params: req.params,
      query: req.query,
      statusCode: res.statusCode,
      duration,
      outcome: res.statusCode < 400 ? 'success' : 'failure',
      userAgent: req.get('user-agent')
    };

    // Add request body for non-GET requests (sanitized)
    if (req.method !== 'GET' && req.body) {
      auditEntry.requestBody = config.audit.sanitizeSensitiveData
        ? sanitizeSensitiveData(req.body)
        : req.body;
    }

    // Add response body summary (not full body for large responses)
    if (body && typeof body === 'object') {
      auditEntry.responseSuccess = body.success;
      if (body.error) {
        auditEntry.responseError = body.error;
      }
    }

    // Log audit entry
    logger.info('API Request', auditEntry);

    // Call original json method
    return originalJson(body);
  };

  next();
};

/**
 * Sanitize sensitive data from logs
 */
const sanitizeSensitiveData = (data) => {
  if (!data || typeof data !== 'object') {
    return data;
  }

  const sensitiveFields = [
    'password',
    'token',
    'apiKey',
    'secret',
    'authorization',
    'cookie'
  ];

  const sanitized = { ...data };

  for (const field of sensitiveFields) {
    if (field in sanitized) {
      sanitized[field] = '***REDACTED***';
    }
  }

  return sanitized;
};

/**
 * Log security events (failed auth, suspicious activity)
 */
const logSecurityEvent = (req, eventType, details) => {
  logger.warn('Security Event', {
    timestamp: new Date().toISOString(),
    eventType,
    ip: req.ip || req.connection.remoteAddress,
    path: req.path,
    method: req.method,
    userAgent: req.get('user-agent'),
    ...details
  });
};

module.exports = {
  auditLog,
  logSecurityEvent,
  sanitizeSensitiveData
};