const config = require('../utils/config');
const logger = require('../utils/logger');

/**
 * Bearer token authentication middleware
 */
const authenticateToken = (req, res, next) => {
  // Skip authentication if not required
  if (!config.security.authentication.required) {
    logger.warn('Authentication is disabled - not recommended for production');
    req.user = { id: 'anonymous', method: 'none' };
    return next();
  }

  const authHeader = req.headers.authorization;

  if (!authHeader) {
    logger.warn('Missing authorization header', {
      ip: req.ip,
      path: req.path
    });

    return res.status(401).json({
      success: false,
      error: 'Authorization header required'
    });
  }

  // Check Bearer token format
  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    logger.warn('Invalid authorization header format', {
      ip: req.ip,
      path: req.path
    });

    return res.status(401).json({
      success: false,
      error: 'Invalid authorization header format. Use: Bearer <token>'
    });
  }

  const token = parts[1];

  // Validate token
  if (!config.security.authToken || token !== config.security.authToken) {
    logger.warn('Invalid authentication token', {
      ip: req.ip,
      path: req.path
    });

    return res.status(401).json({
      success: false,
      error: 'Invalid authentication token'
    });
  }

  // Token is valid
  req.user = {
    id: 'api-user',
    method: 'bearer',
    authenticated: true
  };

  logger.debug('Authentication successful', {
    user: req.user.id,
    path: req.path
  });

  next();
};

/**
 * mTLS client certificate authentication
 */
const authenticateMTLS = (req, res, next) => {
  if (!config.tls.requireClientCert) {
    return next();
  }

  // Check if client certificate is present and authorized
  if (!req.client.authorized) {
    logger.warn('Client certificate not authorized', {
      ip: req.ip,
      error: req.socket.authorizationError
    });

    return res.status(403).json({
      success: false,
      error: 'Client certificate not authorized'
    });
  }

  // Get certificate details
  const cert = req.socket.getPeerCertificate();

  if (!cert || Object.keys(cert).length === 0) {
    logger.warn('No client certificate provided', { ip: req.ip });

    return res.status(403).json({
      success: false,
      error: 'Client certificate required'
    });
  }

  // Check certificate expiration
  const now = new Date();
  const validTo = new Date(cert.valid_to);

  if (validTo < now) {
    logger.warn('Client certificate expired', {
      ip: req.ip,
      cn: cert.subject.CN,
      validTo: cert.valid_to
    });

    return res.status(403).json({
      success: false,
      error: 'Client certificate has expired'
    });
  }

  // Extract user info from certificate
  req.user = {
    id: cert.subject.CN || 'unknown',
    method: 'mtls',
    authenticated: true,
    certificate: {
      subject: cert.subject,
      issuer: cert.issuer,
      validFrom: cert.valid_from,
      validTo: cert.valid_to,
      fingerprint: cert.fingerprint
    }
  };

  logger.info('mTLS authentication successful', {
    user: req.user.id,
    path: req.path
  });

  next();
};

/**
 * Combined authentication middleware
 * Tries mTLS first, falls back to Bearer token
 */
const authenticate = (req, res, next) => {
  // Check if using TLS with client cert requirement
  if (config.tls.enabled && config.tls.requireClientCert) {
    return authenticateMTLS(req, res, next);
  }

  // Use bearer token authentication
  return authenticateToken(req, res, next);
};

/**
 * Role-based authorization middleware
 * (Future enhancement for RBAC)
 */
const authorize = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    // For now, all authenticated users have full access
    // TODO: Implement RBAC based on user roles
    const userRole = req.user.role || 'admin';

    if (allowedRoles.length > 0 && !allowedRoles.includes(userRole)) {
      logger.warn('Insufficient permissions', {
        user: req.user.id,
        role: userRole,
        required: allowedRoles,
        path: req.path
      });

      return res.status(403).json({
        success: false,
        error: 'Insufficient permissions'
      });
    }

    next();
  };
};

module.exports = {
  authenticate,
  authenticateToken,
  authenticateMTLS,
  authorize
};