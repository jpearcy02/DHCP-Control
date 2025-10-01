const path = require('path');
const powershell = require('./powershell');
const logger = require('../utils/logger');

class DHCPService {
  constructor() {
    this.modulePath = path.join(__dirname, '../../modules/DHCPReservationManager');
  }

  /**
   * Get all reservations in a scope
   */
  async getReservations(scopeId) {
    logger.info('Getting DHCP reservations', { scopeId });

    try {
      const scriptPath = path.join(this.modulePath, 'Public', 'Get-DHCPReservations.ps1');
      const result = await powershell.executeScript(scriptPath, { ScopeId: scopeId });

      if (!result.success) {
        throw this.createError(result);
      }

      logger.info('Retrieved DHCP reservations', {
        scopeId,
        count: result.data ? result.data.length : 0
      });

      return result.data || [];
    } catch (error) {
      logger.error('Failed to get reservations', { scopeId, error: error.message });
      throw error;
    }
  }

  /**
   * Get all leases for a scope
   */
  async getLeases(scopeId) {
    logger.info('Getting DHCP leases', { scopeId });

    try {
      const scriptPath = path.join(this.modulePath, 'Public', 'Get-DHCPLeases.ps1');
      const result = await powershell.executeScript(scriptPath, {
        ScopeId: scopeId
      });

      if (!result.success) {
        throw this.createError(result);
      }

      logger.info('Retrieved DHCP leases', { scopeId, count: result.data.count });
      return result.data;
    } catch (error) {
      logger.error('Failed to get leases', { scopeId, error: error.message });
      throw error;
    }
  }

  /**
   * Get a specific reservation by MAC address
   */
  async getReservation(scopeId, clientId) {
    logger.info('Getting DHCP reservation', { scopeId, clientId });

    try {
      const scriptPath = path.join(this.modulePath, 'Public', 'Get-DHCPReservation.ps1');
      const result = await powershell.executeScript(scriptPath, {
        ScopeId: scopeId,
        ClientId: clientId
      });

      if (!result.success) {
        throw this.createError(result);
      }

      logger.info('Retrieved DHCP reservation', { scopeId, clientId });
      return result.data;
    } catch (error) {
      logger.error('Failed to get reservation', { scopeId, clientId, error: error.message });
      throw error;
    }
  }

  /**
   * Create a new DHCP reservation
   */
  async addReservation(scopeId, { ipAddress, clientId, name, description }) {
    logger.info('Creating DHCP reservation', { scopeId, ipAddress, clientId, name });

    try {
      const scriptPath = path.join(this.modulePath, 'Public', 'Add-DHCPReservation.ps1');
      const params = {
        ScopeId: scopeId,
        IPAddress: ipAddress,
        ClientId: clientId
      };

      if (name) params.Name = name;
      if (description) params.Description = description;

      const result = await powershell.executeScript(scriptPath, params);

      if (!result.success) {
        throw this.createError(result);
      }

      logger.info('Created DHCP reservation', { scopeId, ipAddress, clientId });
      return result.data;
    } catch (error) {
      logger.error('Failed to create reservation', {
        scopeId,
        ipAddress,
        clientId,
        error: error.message
      });
      throw error;
    }
  }

  /**
   * Update an existing DHCP reservation
   */
  async updateReservation(scopeId, clientId, updates) {
    logger.info('Updating DHCP reservation', { scopeId, clientId, updates });

    try {
      const scriptPath = path.join(this.modulePath, 'Public', 'Update-DHCPReservation.ps1');
      const params = {
        ScopeId: scopeId,
        ClientId: clientId,
        ...updates
      };

      const result = await powershell.executeScript(scriptPath, params);

      if (!result.success) {
        throw this.createError(result);
      }

      logger.info('Updated DHCP reservation', { scopeId, clientId });
      return result.data;
    } catch (error) {
      logger.error('Failed to update reservation', {
        scopeId,
        clientId,
        error: error.message
      });
      throw error;
    }
  }

  /**
   * Delete a DHCP reservation
   */
  async removeReservation(scopeId, clientId) {
    logger.info('Removing DHCP reservation', { scopeId, clientId });

    try {
      const scriptPath = path.join(this.modulePath, 'Public', 'Remove-DHCPReservation.ps1');
      const result = await powershell.executeScript(scriptPath, {
        ScopeId: scopeId,
        ClientId: clientId
      });

      if (!result.success && result.errorType !== 'NotFound') {
        throw this.createError(result);
      }

      logger.info('Removed DHCP reservation', { scopeId, clientId });
      return true;
    } catch (error) {
      // Idempotent - if not found, consider it successful
      if (error.statusCode === 404) {
        logger.info('Reservation not found (idempotent delete)', { scopeId, clientId });
        return false;
      }

      logger.error('Failed to remove reservation', {
        scopeId,
        clientId,
        error: error.message
      });
      throw error;
    }
  }

  /**
   * Create an error from PowerShell result
   */
  createError(result) {
    const error = new Error(result.message || 'DHCP operation failed');
    error.code = result.errorType || 'DHCP_ERROR';

    // Map error types to HTTP status codes
    const statusCodeMap = {
      'ValidationError': 400,
      'InvalidParameter': 400,
      'DhcpError': 409,
      'NotFound': 404,
      'PermissionDenied': 403,
      'UnexpectedError': 500
    };

    error.statusCode = statusCodeMap[result.errorType] || 500;
    error.details = result;

    return error;
  }
}

module.exports = new DHCPService();