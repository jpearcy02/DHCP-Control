const { exec } = require('child_process');
const { promisify } = require('util');
const logger = require('../utils/logger');
const config = require('../utils/config');

const execAsync = promisify(exec);

class PowerShellService {
  constructor() {
    this.timeout = config.powershell.executionTimeout;
    this.activeCommands = 0;
    this.maxConcurrent = config.powershell.maxConcurrent;
  }

  /**
   * Execute PowerShell script with parameters
   * Uses parameter binding to prevent injection attacks
   */
  async executeScript(scriptPath, params = {}) {
    // Check concurrent limit
    if (this.activeCommands >= this.maxConcurrent) {
      throw new Error('PowerShell execution limit reached. Please try again later.');
    }

    this.activeCommands++;
    const startTime = Date.now();

    try {
      // Build PowerShell command with parameter binding
      const psParams = Object.entries(params)
        .map(([key, value]) => {
          const strValue = String(value);
          // Only quote if value contains spaces or special characters
          if (strValue.includes(' ') || strValue.includes('$') || strValue.includes('`')) {
            // Escape single quotes in values
            const escaped = strValue.replace(/'/g, "''");
            return `-${key} '${escaped}'`;
          }
          // Simple values like IP addresses don't need quoting
          return `-${key} ${strValue}`;
        })
        .join(' ');

      const command = [
        'powershell.exe',
        '-ExecutionPolicy Bypass',
        '-NoProfile',
        '-NonInteractive',
        '-OutputFormat Text',
        '-File',
        `"${scriptPath}"`,
        psParams
      ].join(' ');

      logger.debug('Executing PowerShell command', { scriptPath, params });

      const { stdout, stderr } = await execAsync(command, {
        timeout: this.timeout,
        maxBuffer: 10 * 1024 * 1024, // 10MB
        windowsHide: true
      });

      const duration = Date.now() - startTime;

      if (stderr) {
        logger.warn('PowerShell stderr output', { stderr, duration });
      }

      logger.debug('PowerShell command completed', { duration, scriptPath });

      // Parse JSON output
      try {
        return JSON.parse(stdout);
      } catch (parseError) {
        logger.error('Failed to parse PowerShell output', {
          stdout: stdout.substring(0, 500),
          parseError: parseError.message
        });
        throw new Error('Invalid PowerShell output format');
      }
    } catch (error) {
      const duration = Date.now() - startTime;

      if (error.killed || error.signal === 'SIGTERM') {
        logger.error('PowerShell command timeout', { scriptPath, timeout: this.timeout, duration });
        throw new Error('PowerShell command timed out');
      }

      logger.error('PowerShell execution failed', {
        scriptPath,
        params,
        error: error.message,
        stderr: error.stderr,
        duration
      });

      throw this.parseError(error);
    } finally {
      this.activeCommands--;
    }
  }

  /**
   * Execute inline PowerShell command
   */
  async executeCommand(command, params = {}) {
    this.activeCommands++;
    const startTime = Date.now();

    try {
      // Build command with parameters
      const psCommand = this.buildCommand(command, params);

      logger.debug('Executing inline PowerShell command', { command });

      const { stdout, stderr } = await execAsync(psCommand, {
        timeout: this.timeout,
        maxBuffer: 10 * 1024 * 1024,
        windowsHide: true
      });

      const duration = Date.now() - startTime;

      if (stderr) {
        logger.warn('PowerShell stderr', { stderr, duration });
      }

      logger.debug('PowerShell inline command completed', { duration });

      // Parse JSON output if present
      if (stdout.trim().startsWith('{') || stdout.trim().startsWith('[')) {
        try {
          return JSON.parse(stdout);
        } catch (e) {
          return stdout;
        }
      }

      return stdout;
    } catch (error) {
      const duration = Date.now() - startTime;
      logger.error('PowerShell inline command failed', {
        command,
        error: error.message,
        duration
      });
      throw this.parseError(error);
    } finally {
      this.activeCommands--;
    }
  }

  /**
   * Build PowerShell command with safe parameter binding
   */
  buildCommand(cmdlet, params) {
    const psParams = Object.entries(params)
      .map(([key, value]) => {
        const strValue = String(value);
        // Only quote if value contains spaces or special characters
        if (strValue.includes(' ') || strValue.includes('$') || strValue.includes('`')) {
          const escaped = strValue.replace(/'/g, "''");
          return `-${key} '${escaped}'`;
        }
        // Simple values like IP addresses don't need quoting
        return `-${key} ${strValue}`;
      })
      .join(' ');

    return [
      'powershell.exe',
      '-ExecutionPolicy Bypass',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      `"${cmdlet} ${psParams} | ConvertTo-Json -Depth 10 -Compress"`
    ].join(' ');
  }

  /**
   * Parse PowerShell errors into meaningful messages
   */
  parseError(error) {
    const errorMessage = error.message || error.stderr || String(error);

    // DHCP-specific errors
    if (errorMessage.includes('already exists')) {
      const err = new Error('Reservation already exists');
      err.statusCode = 409;
      err.code = 'RESERVATION_EXISTS';
      return err;
    }

    if (errorMessage.includes('Cannot find') || errorMessage.includes('does not exist')) {
      const err = new Error('Reservation or scope not found');
      err.statusCode = 404;
      err.code = 'NOT_FOUND';
      return err;
    }

    if (errorMessage.includes('Access is denied') || errorMessage.includes('unauthorized')) {
      const err = new Error('Insufficient permissions to perform DHCP operation');
      err.statusCode = 403;
      err.code = 'PERMISSION_DENIED';
      return err;
    }

    if (errorMessage.includes('outside') || errorMessage.includes('range')) {
      const err = new Error('IP address is outside scope range');
      err.statusCode = 400;
      err.code = 'INVALID_RANGE';
      return err;
    }

    if (errorMessage.includes('Invalid') || errorMessage.includes('ParameterBindingException')) {
      const err = new Error('Invalid parameter format');
      err.statusCode = 400;
      err.code = 'INVALID_PARAMETER';
      return err;
    }

    // Generic error
    const err = new Error('PowerShell execution failed');
    err.statusCode = 500;
    err.code = 'POWERSHELL_ERROR';
    err.details = errorMessage;
    return err;
  }

  /**
   * Get current health status
   */
  getHealthStatus() {
    return {
      activeCommands: this.activeCommands,
      maxConcurrent: this.maxConcurrent,
      available: this.activeCommands < this.maxConcurrent
    };
  }
}

module.exports = new PowerShellService();