# DHCP REST Agent - Quick Start Guide

Get your DHCP REST API up and running in 5 minutes!

## Prerequisites

- Windows Server 2016 or later
- DHCP Server role installed
- Node.js 18.x or later
- PowerShell 5.1 or later
- Administrator access

## Step 1: Install Dependencies

Open PowerShell as Administrator and navigate to the project directory:

```powershell
cd "D:\Code Projects\DHCP Control"
npm install
```

## Step 2: Generate Test Certificates

```powershell
.\scripts\generate-test-certs.ps1
```

This creates self-signed TLS certificates in the `certs/` directory.

## Step 3: Configure Authentication

Copy the example environment file:

```powershell
copy .env.example .env
```

Generate a secure authentication token:

```powershell
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

Edit `.env` and set your `AUTH_TOKEN`:

```
AUTH_TOKEN=your-generated-token-here
```

## Step 4: Start the Server

Development mode (with auto-reload):

```powershell
npm run dev
```

Or production mode:

```powershell
npm start
```

You should see:

```
============================================================
  DHCP REST Agent
  Windows DHCP Server REST API
  Version: 1.0.0
  Environment: development
============================================================
DHCP REST Agent started
  protocol: https
  host: 0.0.0.0
  port: 8443
  ...
```

## Step 5: Test the API

### Check Health

```powershell
curl -k https://localhost:8443/health
```

### Test with PowerShell Script

```powershell
.\scripts\test-api.ps1 -Token "your-token" -TestScopeId "192.168.1.0"
```

Replace `192.168.1.0` with an actual scope on your DHCP server.

### Manual API Tests

List reservations:

```powershell
$headers = @{ "Authorization" = "Bearer your-token" }
Invoke-RestMethod -Uri "https://localhost:8443/scopes/192.168.1.0/reservations" -Headers $headers -SkipCertificateCheck
```

Create a reservation:

```powershell
$body = @{
    ipAddress = "192.168.1.100"
    clientId = "AA-BB-CC-DD-EE-FF"
    name = "TestDevice"
    description = "Test reservation"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://localhost:8443/scopes/192.168.1.0/reservations" `
    -Method Post -Headers $headers -Body $body -ContentType "application/json" -SkipCertificateCheck
```

## Step 6: Install as Windows Service (Optional)

For production deployment:

```powershell
.\scripts\install-service.ps1
```

This installs the application as a Windows Service that:
- Starts automatically on boot
- Restarts on failure
- Logs to `logs/` directory

Check service status:

```powershell
Get-Service DHCPRestAgent
```

View logs:

```powershell
Get-Content ".\logs\service-stdout.log" -Tail 50
```

## Troubleshooting

### "Port 8443 already in use"

Check what's using the port:

```powershell
netstat -ano | findstr :8443
```

Kill the process or change the port in `config/default.json`.

### "DHCP PowerShell cmdlets not available"

Verify DHCP Server role is installed:

```powershell
Get-WindowsFeature DHCP
```

Install if needed:

```powershell
Install-WindowsFeature DHCP -IncludeManagementTools
```

### "Authentication failed"

Make sure your token matches what's in the `.env` file and you're using the correct header format:

```
Authorization: Bearer your-token-here
```

### "Certificate errors"

For testing with self-signed certificates, use `-SkipCertificateCheck` in PowerShell or `-k` with curl.

For production, use proper CA-signed certificates.

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Review [CLAUDE.md](CLAUDE.md) for development guidance
- Set up monitoring and alerting
- Configure proper TLS certificates for production
- Implement role-based access control (RBAC)
- Set up centralized logging

## Quick Reference

### Environment Variables

```
NODE_ENV=development|production
PORT=8443
AUTH_TOKEN=your-secure-token
LOG_LEVEL=info|debug|warn|error
```

### Useful Commands

```powershell
# Development
npm run dev              # Start with auto-reload
npm test                 # Run tests
npm run lint             # Check code quality

# Service Management
Start-Service DHCPRestAgent
Stop-Service DHCPRestAgent
Restart-Service DHCPRestAgent
Get-Service DHCPRestAgent

# Uninstall Service
.\scripts\uninstall-service.ps1
```

### API Endpoints

```
GET    /health                                    # Health check
GET    /scopes/:scopeId/reservations              # List all
GET    /scopes/:scopeId/reservations/:clientId    # Get one
POST   /scopes/:scopeId/reservations              # Create
PUT    /scopes/:scopeId/reservations/:clientId    # Update
DELETE /scopes/:scopeId/reservations/:clientId    # Delete
```

All API requests require:

```
Authorization: Bearer <token>
Content-Type: application/json
```

## Support

Having issues? Check:

1. Logs in `./logs/` directory
2. Windows Event Viewer (Application log, source: DHCPRestAgent)
3. Service status: `Get-Service DHCPRestAgent`
4. Health endpoint: `https://localhost:8443/health`

For detailed troubleshooting, see [README.md](README.md#troubleshooting).