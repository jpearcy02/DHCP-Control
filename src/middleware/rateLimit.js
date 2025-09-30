const rateLimit = require('express-rate-limit');
const config = require('../utils/config');
const logger = require('../utils/logger');

/**
 * Global rate limiter
 */
const globalLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.maxRequests,
  message: config.rateLimit.message,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => !config.rateLimit.enabled,
  handler: (req, res) => {
    logger.warn('Rate limit exceeded', {
      ip: req.ip,
      path: req.path,
      user: req.user ? req.user.id : 'anonymous'
    });

    res.status(429).json({
      success: false,
      error: config.rateLimit.message,
      retryAfter: Math.ceil(config.rateLimit.windowMs / 1000)
    });
  }
});

/**
 * Stricter rate limiter for write operations
 */
const writeLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: Math.floor(config.rateLimit.maxRequests / 2),
  message: 'Too many write operations from this IP',
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => !config.rateLimit.enabled || req.method === 'GET',
  handler: (req, res) => {
    logger.warn('Write rate limit exceeded', {
      ip: req.ip,
      path: req.path,
      method: req.method,
      user: req.user ? req.user.id : 'anonymous'
    });

    res.status(429).json({
      success: false,
      error: 'Too many write operations. Please try again later.',
      retryAfter: Math.ceil(config.rateLimit.windowMs / 1000)
    });
  }
});

module.exports = {
  globalLimiter,
  writeLimiter
};