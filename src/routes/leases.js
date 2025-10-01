const express = require('express');
const Joi = require('joi');
const dhcpService = require('../services/dhcp');
const { validate, validateParams } = require('../middleware/validation');
const { asyncHandler } = require('../middleware/errorHandler');

const router = express.Router();

// Validation schemas
const schemas = {
  scopeId: Joi.string()
    .pattern(/^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$/)
    .required()
    .messages({
      'string.pattern.base': 'Invalid IPv4 scope ID format'
    })
};

/**
 * GET /scopes/:scopeId/leases
 * Get all DHCP leases for a scope
 */
router.get(
  '/:scopeId/leases',
  validateParams(Joi.object({ scopeId: schemas.scopeId })),
  asyncHandler(async (req, res) => {
    const { scopeId } = req.params;

    const leases = await dhcpService.getLeases(scopeId);

    res.json({
      success: true,
      data: leases.leases,
      count: leases.count,
      scope: scopeId
    });
  })
);

module.exports = router;
