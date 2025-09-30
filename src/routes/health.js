const express = require('express');
const powershell = require('../services/powershell');
const { asyncHandler } = require('../middleware/errorHandler');
const config = require('../utils/config');
const fs = require('fs');

const router = express.Router();

/**
 * GET /health
 * Health check endpoint for monitoring
 */
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const startTime = Date.now();
    const checks = {};

    // Check PowerShell availability
    try {
      const psCommand = 'powershell.exe -Command "Get-Date | ConvertTo-Json"';
      const { exec } = require('child_process');
      await new Promise((resolve, reject) => {
        exec(psCommand, { timeout: 5000 }, (error, stdout) => {
          if (error) reject(error);
          else resolve(stdout);
        });
      });

      checks.powershell = {
        status: 'healthy',
        lastCheck: new Date().toISOString(),
        ...powershell.getHealthStatus()
      };
    } catch (error) {
      checks.powershell = {
        status: 'unhealthy',
        error: error.message
      };
    }

    // Check DHCP Server service (Windows)
    try {
      const dhcpCheck = 'powershell.exe -Command "Get-Service DHCPServer | Select-Object Status | ConvertTo-Json"';
      const { exec } = require('child_process');
      const result = await new Promise((resolve, reject) => {
        exec(dhcpCheck, { timeout: 5000 }, (error, stdout, stderr) => {
          if (error) reject(error);
          else resolve(stdout);
        });
      });

      const serviceStatus = JSON.parse(result);
      checks.dhcpServer = {
        status: serviceStatus.Status === 'Running' ? 'healthy' : 'unhealthy',
        serviceStatus: serviceStatus.Status
      };
    } catch (error) {
      checks.dhcpServer = {
        status: 'unknown',
        error: error.message
      };
    }

    // Check TLS certificates
    if (config.tls.enabled) {
      try {
        const certExists = fs.existsSync(config.tls.certPath);
        const keyExists = fs.existsSync(config.tls.keyPath);

        checks.certificates = {
          status: certExists && keyExists ? 'healthy' : 'unhealthy',
          certPath: config.tls.certPath,
          certExists,
          keyExists
        };
      } catch (error) {
        checks.certificates = {
          status: 'error',
          error: error.message
        };
      }
    }

    // Check disk space for logs
    try {
      const { execSync } = require('child_process');
      const driveInfo = execSync(
        `powershell -Command "Get-PSDrive -Name D | Select-Object @{N='Free';E={$_.Free/1GB}} | ConvertTo-Json"`,
        { encoding: 'utf8', timeout: 5000 }
      );
      const drive = JSON.parse(driveInfo);

      checks.diskSpace = {
        status: drive.Free > 1 ? 'healthy' : 'warning',
        freeSpaceGB: Math.round(drive.Free * 100) / 100
      };
    } catch (error) {
      checks.diskSpace = {
        status: 'unknown',
        error: error.message
      };
    }

    // Overall health status
    const allHealthy = Object.values(checks).every(
      (check) => check.status === 'healthy' || check.status === 'warning'
    );

    const responseTime = Date.now() - startTime;

    const healthResponse = {
      status: allHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      version: require('../../package.json').version,
      uptime: process.uptime(),
      responseTime,
      checks,
      environment: config.service.environment
    };

    // Return 503 if unhealthy
    const statusCode = allHealthy ? 200 : 503;
    res.status(statusCode).json(healthResponse);
  })
);

/**
 * GET /health/ready
 * Readiness check for load balancers
 */
router.get('/ready', (req, res) => {
  // Simple check - is the server responding?
  res.json({
    ready: true,
    timestamp: new Date().toISOString()
  });
});

/**
 * GET /health/live
 * Liveness check for Kubernetes/Docker
 */
router.get('/live', (req, res) => {
  res.json({
    alive: true,
    timestamp: new Date().toISOString()
  });
});

module.exports = router;