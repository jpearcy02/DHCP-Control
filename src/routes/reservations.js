const express = require('express');
const dhcpService = require('../services/dhcp');
const { validate, validateParams, schemas, normalizeMACAddress } = require('../middleware/validation');
const { asyncHandler } = require('../middleware/errorHandler');
const Joi = require('joi');

const router = express.Router();

/**
 * GET /scopes/:scopeId/reservations
 * List all reservations in a scope
 */
router.get(
  '/:scopeId/reservations',
  validateParams(Joi.object({ scopeId: schemas.scopeId })),
  asyncHandler(async (req, res) => {
    const { scopeId } = req.params;

    const reservations = await dhcpService.getReservations(scopeId);

    res.json({
      success: true,
      data: reservations,
      count: reservations.length,
      scope: scopeId
    });
  })
);

/**
 * GET /scopes/:scopeId/reservations/:clientId
 * Get a specific reservation by MAC address
 */
router.get(
  '/:scopeId/reservations/:clientId',
  validateParams(
    Joi.object({
      scopeId: schemas.scopeId,
      clientId: schemas.clientId
    })
  ),
  asyncHandler(async (req, res) => {
    const { scopeId, clientId } = req.params;
    const normalizedClientId = normalizeMACAddress(clientId);

    const reservation = await dhcpService.getReservation(scopeId, normalizedClientId);

    if (!reservation) {
      return res.status(404).json({
        success: false,
        error: 'Reservation not found',
        scope: scopeId,
        clientId: normalizedClientId
      });
    }

    res.json({
      success: true,
      data: reservation
    });
  })
);

/**
 * POST /scopes/:scopeId/reservations
 * Create a new DHCP reservation
 */
router.post(
  '/:scopeId/reservations',
  validateParams(Joi.object({ scopeId: schemas.scopeId })),
  validate(schemas.reservation),
  asyncHandler(async (req, res) => {
    const { scopeId } = req.params;
    const { ipAddress, clientId, name, description } = req.body;

    // Normalize MAC address
    const normalizedClientId = normalizeMACAddress(clientId);

    const reservation = await dhcpService.addReservation(scopeId, {
      ipAddress,
      clientId: normalizedClientId,
      name,
      description
    });

    res.status(201).json({
      success: true,
      data: reservation,
      message: 'Reservation created successfully'
    });
  })
);

/**
 * PUT /scopes/:scopeId/reservations/:clientId
 * Update an existing DHCP reservation
 */
router.put(
  '/:scopeId/reservations/:clientId',
  validateParams(
    Joi.object({
      scopeId: schemas.scopeId,
      clientId: schemas.clientId
    })
  ),
  validate(schemas.reservationUpdate),
  asyncHandler(async (req, res) => {
    const { scopeId, clientId } = req.params;
    const normalizedClientId = normalizeMACAddress(clientId);

    const reservation = await dhcpService.updateReservation(
      scopeId,
      normalizedClientId,
      req.body
    );

    res.json({
      success: true,
      data: reservation,
      message: 'Reservation updated successfully'
    });
  })
);

/**
 * DELETE /scopes/:scopeId/reservations/:clientId
 * Delete a DHCP reservation
 */
router.delete(
  '/:scopeId/reservations/:clientId',
  validateParams(
    Joi.object({
      scopeId: schemas.scopeId,
      clientId: schemas.clientId
    })
  ),
  asyncHandler(async (req, res) => {
    const { scopeId, clientId } = req.params;
    const normalizedClientId = normalizeMACAddress(clientId);

    await dhcpService.removeReservation(scopeId, normalizedClientId);

    // 204 No Content - idempotent delete
    res.status(204).send();
  })
);

module.exports = router;