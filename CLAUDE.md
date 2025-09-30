# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Windows DHCP REST Agent - A secure REST API service that runs locally on Windows Server 2016 DHCP servers to expose CRUD operations for DHCP reservations via PowerShell cmdlets.

**Target Environment:** Windows Server 2016 (DHCP role installed)
**Architecture:** Node.js + Express → PowerShell cmdlets → Windows DHCP Server
**Deployment:** Windows Service (via nssm or sc.exe)
**API Endpoint:** https://localhost:8443

## Architecture

The system consists of three layers:

1. **REST API Layer** (Express.js)
   - Handles HTTP requests/responses
   - Validates inputs (MAC addresses, IPv4 addresses)
   - Enforces authentication (mTLS client certificates initially)
   - Returns structured JSON responses with appropriate HTTP status codes

2. **PowerShell Integration Layer**
   - Wraps native DHCP cmdlets: `Get-DhcpServerv4Reservation`, `Add-DhcpServerv4Reservation`, `Set-DhcpServerv4Reservation`, `Remove-DhcpServerv4Reservation`
   - Uses parameter binding (never string interpolation) to prevent injection attacks
   - Converts PowerShell output to JSON for API consumption

3. **Audit Logging**
   - Logs all API calls (method, parameters, user, outcome)
   - Writes to Windows Event Log (Application channel) and/or local JSON log files

## API Endpoints

- `GET /scopes/{scope}/reservations` - List all reservations in a scope
- `POST /scopes/{scope}/reservations` - Create new reservation (201 on success, 409 on duplicate)
- `PUT /scopes/{scope}/reservations/{clientId}` - Update existing reservation (200 on success, 404 if not found)
- `DELETE /scopes/{scope}/reservations/{clientId}` - Remove reservation

All endpoints accept and return JSON. OpenAPI specification should be maintained.

## Input Validation Requirements

**MAC Address Pattern:** `^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$`
**IPv4 Address Pattern:** `^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$`

Validation must occur in middleware before any PowerShell execution.

## Security Considerations

- **Authentication:** Start with mTLS client certificates; may expand to Windows Integrated Auth (Kerberos/NTLM) or API keys
- **TLS Required:** Self-signed certificates acceptable for lab environment
- **Command Injection Prevention:** Always use PowerShell parameter binding, never concatenate raw strings
- **Firewall:** Port 8443 should only be accessible from management subnet
- **Audit Trail:** Every change must be logged with user identity and action details

## Windows Service Deployment

The Node.js application runs as a Windows Service for automatic restart and system integration. Use `nssm` (Non-Sucking Service Manager) or Windows `sc.exe` for service registration. Deployment scripts should handle:

- Service installation and configuration
- Firewall rule creation
- TLS certificate generation and binding
- Service startup and health verification

## Testing Requirements

- **Unit Tests:** API validation, error codes, JSON schema compliance
- **Integration Tests:** Verify actual DHCP reservation creation/modification via DHCP console
- **Negative Tests:** Invalid inputs, duplicate reservations, permission failures
- **Performance Tests:** Handle 50+ concurrent requests
- Maintain Postman collection for manual API testing

## Development Workflow

Components can be developed in parallel:
1. API specification (OpenAPI/Swagger)
2. PowerShell helper module with cmdlet wrappers
3. Express middleware for validation and authentication
4. Logging infrastructure
5. Deployment automation scripts
6. Test suite (unit, integration, performance)

## Future Enhancement Areas

- Web UI dashboard (React/HTML frontend)
- Central controller to manage multiple DHCP server agents
- Bulk import/export (CSV format)
- Extended functionality: scope management, lease queries, server options