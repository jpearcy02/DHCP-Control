const Joi = require('joi');
const config = require('../utils/config');
const logger = require('../utils/logger');

// Validation schemas
const schemas = {
  reservation: Joi.object({
    ipAddress: Joi.string()
      .pattern(new RegExp(config.security.validation.ipv4Pattern))
      .required()
      .messages({
        'string.pattern.base': 'Invalid IPv4 address format',
        'any.required': 'IP address is required'
      }),

    clientId: Joi.string()
      .pattern(new RegExp(config.security.validation.macPattern))
      .required()
      .messages({
        'string.pattern.base': 'Invalid MAC address format (use format: AA-BB-CC-DD-EE-FF or AA:BB:CC:DD:EE:FF)',
        'any.required': 'MAC address (clientId) is required'
      }),

    name: Joi.string()
      .max(255)
      .optional()
      .messages({
        'string.max': 'Name must be less than 255 characters'
      }),

    description: Joi.string()
      .max(500)
      .optional()
      .messages({
        'string.max': 'Description must be less than 500 characters'
      })
  }),

  reservationUpdate: Joi.object({
    ipAddress: Joi.string()
      .pattern(new RegExp(config.security.validation.ipv4Pattern))
      .optional()
      .messages({
        'string.pattern.base': 'Invalid IPv4 address format'
      }),

    name: Joi.string()
      .max(255)
      .optional()
      .messages({
        'string.max': 'Name must be less than 255 characters'
      }),

    description: Joi.string()
      .max(500)
      .optional()
      .messages({
        'string.max': 'Description must be less than 500 characters'
      })
  }).min(1).messages({
    'object.min': 'At least one field must be provided for update'
  }),

  scopeId: Joi.string()
    .pattern(new RegExp(config.security.validation.ipv4Pattern))
    .required()
    .messages({
      'string.pattern.base': 'Invalid scope ID format (must be valid IPv4 address)',
      'any.required': 'Scope ID is required'
    }),

  clientId: Joi.string()
    .pattern(new RegExp(config.security.validation.macPattern))
    .required()
    .messages({
      'string.pattern.base': 'Invalid MAC address format',
      'any.required': 'Client ID (MAC address) is required'
    })
};

/**
 * Validate request body against schema
 */
const validate = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false,
      stripUnknown: true
    });

    if (error) {
      const errors = error.details.map((detail) => ({
        field: detail.path.join('.'),
        message: detail.message
      }));

      logger.warn('Validation failed', {
        path: req.path,
        errors,
        body: req.body
      });

      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors
      });
    }

    // Sanitize input
    req.body = sanitizeInput(value);
    next();
  };
};

/**
 * Validate route parameters
 */
const validateParams = (paramSchema) => {
  return (req, res, next) => {
    const { error, value } = paramSchema.validate(req.params, {
      abortEarly: false
    });

    if (error) {
      const errors = error.details.map((detail) => ({
        field: detail.path.join('.'),
        message: detail.message
      }));

      logger.warn('Parameter validation failed', {
        path: req.path,
        errors,
        params: req.params
      });

      return res.status(400).json({
        success: false,
        error: 'Invalid parameters',
        details: errors
      });
    }

    req.params = value;
    next();
  };
};

/**
 * Sanitize input to prevent XSS
 */
const sanitizeInput = (data) => {
  if (typeof data === 'string') {
    // Remove HTML tags and script content
    return data
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<[^>]+>/g, '')
      .trim();
  }

  if (typeof data === 'object' && data !== null) {
    const sanitized = {};
    for (const [key, value] of Object.entries(data)) {
      sanitized[key] = sanitizeInput(value);
    }
    return sanitized;
  }

  return data;
};

/**
 * Normalize MAC address format
 */
const normalizeMACAddress = (mac) => {
  // Convert to uppercase and use dash separator
  return mac.toUpperCase().replace(/:/g, '-');
};

/**
 * Validate IPv4 address format
 */
const validateIPv4 = (ip) => {
  const pattern = new RegExp(config.security.validation.ipv4Pattern);
  return pattern.test(ip);
};

/**
 * Validate MAC address format
 */
const validateMAC = (mac) => {
  const pattern = new RegExp(config.security.validation.macPattern);
  return pattern.test(mac);
};

/**
 * Check if IP is in private range (informational, not blocking)
 */
const isPrivateIP = (ip) => {
  const parts = ip.split('.').map(Number);
  return (
    parts[0] === 10 ||
    (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) ||
    (parts[0] === 192 && parts[1] === 168)
  );
};

module.exports = {
  schemas,
  validate,
  validateParams,
  sanitizeInput,
  normalizeMACAddress,
  validateIPv4,
  validateMAC,
  isPrivateIP
};