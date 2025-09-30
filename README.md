# DHCP REST Agent

Secure REST API for managing Windows DHCP Server reservations.

## Overview

This project provides a production-ready REST API interface for Windows Server DHCP management. It exposes CRUD operations for DHCP reservations through a secure HTTPS endpoint with authentication, rate limiting, and comprehensive audit logging.

## Features

- ✅ RESTful API for DHCP reservation management (Create, Read, Update, Delete)
- ✅ Secure authentication (Bearer tokens or mTLS client certificates)
- ✅ Input validation and sanitization
- ✅ Rate limiting to prevent abuse
- ✅ Comprehensive audit logging (file + Windows Event Log)
- ✅ Health check endpoints for monitoring
- ✅ PowerShell module with proper error handling
- ✅ Idempotent operations (safe to retry)
- ✅ Structured JSON responses
- ✅ Production-ready security headers

## Requirements

- Windows Server 2016 or later
- DHCP Server role installed
- Node.js 18.x or later
- PowerShell 5.1 or later
- Administrator privileges (for DHCP management)

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Generate TLS Certificates

For lab/testing:

```powershell
.\scripts\generate-test-certs.ps1
```

For production, use proper CA-signed certificates.

### 3. Configure Environment

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Edit `.env` and set your authentication token:

```
AUTH_TOKEN=your-secure-random-token-here
```

Generate a secure token:

```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

### 4. Start the Server

Development mode:

```bash
npm run dev
```

Production mode:

```bash
npm start
```

## API Endpoints

### Health Check

```
GET /health
```

Returns service health status and diagnostics.

### List Reservations

```
GET /scopes/:scopeId/reservations
Authorization: Bearer <token>
```

Example:

```bash
curl -k https://localhost:8443/scopes/192.168.1.0/reservations \
  -H "Authorization: Bearer your-token"
```

### Get Specific Reservation

```
GET /scopes/:scopeId/reservations/:clientId
Authorization: Bearer <token>
```

### Create Reservation

```
POST /scopes/:scopeId/reservations
Authorization: Bearer <token>
Content-Type: application/json

{
  "ipAddress": "192.168.1.100",
  "clientId": "AA-BB-CC-DD-EE-FF",
  "name": "Server01",
  "description": "Production server"
}
```

### Update Reservation

```
PUT /scopes/:scopeId/reservations/:clientId
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "UpdatedName",
  "description": "Updated description"
}
```

### Delete Reservation

```
DELETE /scopes/:scopeId/reservations/:clientId
Authorization: Bearer <token>
```

Returns `204 No Content` on success (idempotent).

## Configuration

Configuration is managed through JSON files in the `config/` directory:

- `default.json` - Base configuration
- `production.json` - Production overrides
- `local.json` - Local overrides (not committed)

Environment variables override JSON config.

### Key Configuration Options

```json
{
  "service": {
    "port": 8443,
    "host": "0.0.0.0"
  },
  "tls": {
    "enabled": true,
    "requireClientCert": false
  },
  "rateLimit": {
    "enabled": true,
    "maxRequests": 100,
    "windowMs": 60000
  },
  "logging": {
    "level": "info",
    "windowsEventLog": {
      "enabled": true
    }
  }
}
```

## Security

### Authentication

Two authentication methods supported:

1. **Bearer Token** (default)
   - Set `AUTH_TOKEN` environment variable
   - Include in request: `Authorization: Bearer <token>`

2. **mTLS Client Certificates**
   - Set `tls.requireClientCert: true` in config
   - Provide client certificate with request

### Rate Limiting

- Global: 100 requests per minute per IP
- Write operations: 50 requests per minute per IP

### Input Validation

- MAC addresses: `AA-BB-CC-DD-EE-FF` or `AA:BB:CC:DD:EE:FF`
- IPv4 addresses: Standard dotted notation
- XSS protection: HTML tags stripped
- SQL injection: Parameter binding (no string concatenation)

## Logging

Logs are written to:

1. **File logs** (`./logs/`)
   - `dhcp-agent-YYYY-MM-DD.log` - Application log (30 days)
   - `error-YYYY-MM-DD.log` - Error log (90 days)
   - `audit-YYYY-MM-DD.log` - Audit log (365 days)

2. **Windows Event Log** (optional)
   - Source: `DHCPRestAgent`
   - Log: Application

3. **Console** (development only)

## Deployment

### Windows Service Installation

Use the provided script:

```powershell
.\scripts\install-service.ps1
```

This uses `nssm` (Non-Sucking Service Manager) to create a Windows Service with:
- Automatic startup
- Automatic restart on failure
- Log rotation

### Manual Installation

```powershell
# Install nssm
choco install nssm

# Install service
nssm install DHCPRestAgent "C:\Program Files\nodejs\node.exe" "D:\Code Projects\DHCP Control\src\server.js"
nssm set DHCPRestAgent AppDirectory "D:\Code Projects\DHCP Control"
nssm set DHCPRestAgent AppEnvironmentExtra NODE_ENV=production

# Start service
Start-Service DHCPRestAgent
```

## Testing

```bash
# Run all tests
npm test

# Unit tests only
npm run test:unit

# Integration tests (requires DHCP server)
npm run test:integration

# Security tests
npm run test:security
```

## Troubleshooting

### Service Won't Start

1. Check logs: `.\logs\error-*.log`
2. Verify DHCP Server role is installed
3. Ensure port 8443 is available
4. Check TLS certificates exist

### PowerShell Errors

1. Verify DHCP PowerShell module:

```powershell
Get-Module -ListAvailable DhcpServer
```

2. Test DHCP cmdlets:

```powershell
Get-DhcpServerv4Scope
```

3. Check permissions (must run as administrator)

### Authentication Failures

1. Verify `AUTH_TOKEN` is set correctly
2. Check token in request header
3. Review audit logs for failed attempts

## Performance

Expected performance on Windows Server 2016:

- **Latency**: 200-500ms per request (PowerShell overhead)
- **Throughput**: 20-50 requests/second
- **Concurrent requests**: Up to 10 simultaneous

For better performance (10-100x faster), consider migrating to .NET Core with in-process PowerShell runspaces.

## Architecture

```
Client Request
    ↓
Express API (validation, auth, rate limiting)
    ↓
PowerShell Service (spawns powershell.exe)
    ↓
PowerShell Module (DHCPReservationManager)
    ↓
DHCP Server Cmdlets
    ↓
Windows DHCP Server
```

## License

MIT

## Support

For issues and questions, see [CLAUDE.md](CLAUDE.md) for development guidance.