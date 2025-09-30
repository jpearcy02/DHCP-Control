🗂 Development Plan: Windows DHCP REST Agent (Local Agent Approach)

Environment:

Windows Server 2016 (x2 servers, DHCP role installed).

Lab context, so we can move fast but keep structure for later hardening.

Overall Goal:
Expose a secure REST API on each DHCP server that allows creating, reading, updating, and deleting DHCP reservations via PowerShell cmdlets.

1. Architecture & Core Service

Domain Expert: Windows Server Systems Architect

Decide between Node.js + Express + PowerShell calls vs .NET Core Web API with PowerShell SDK.

For a lab, Node.js + Express is simpler, faster to iterate, easier for you to test and extend.

Run as a Windows Service (using nssm or sc create) with automatic restart.

Expose REST API on https://localhost:8443 (per server).

Deliverables:

High-level system diagram (API → PowerShell → DHCP Server).

Windows Service wrapper instructions.

2. API Design

Domain Expert: REST API Designer

Define endpoints for CRUD operations:

GET /scopes/{scope}/reservations

POST /scopes/{scope}/reservations

PUT /scopes/{scope}/reservations/{clientId}

DELETE /scopes/{scope}/reservations/{clientId}

Input/output strictly JSON.

Include error handling and meaningful HTTP codes.

Idempotent behavior:

POST returns 201 on new, 409 on duplicate.

PUT returns 200 if updated, 404 if not found.

Deliverables:

API specification in OpenAPI (Swagger) format.

Example requests/responses.

3. PowerShell Integration Layer

Domain Expert: PowerShell / Windows Automation SME

Wrap native DHCP cmdlets:

Get-DhcpServerv4Reservation

Add-DhcpServerv4Reservation

Set-DhcpServerv4Reservation

Remove-DhcpServerv4Reservation

Ensure parameter binding, not string interpolation (avoid injection).

Standardize outputs → JSON (ConvertTo-Json).

Deliverables:

PowerShell helper script/module with tested cmdlets.

Example output parsing for the API layer.

4. Validation & Input Sanitization

Domain Expert: Security Engineer

Validate inputs:

MAC address regex: ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$

IPv4 regex: ^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$

Prevent command injection by never concatenating raw strings into PowerShell.

Require TLS (self-signed for lab, CA later).

Deliverables:

Validation middleware.

TLS bootstrap script (creates self-signed cert + binds to service).

5. Authentication & Authorization

Domain Expert: Identity & Access Control Specialist

Lab: start with mTLS client certs.

Later: support Windows Integrated Auth (Kerberos/NTLM) or API keys stored in secure location.

Ensure logs track who made change + what change was made.

Deliverables:

Auth design doc.

Implementation in Express middleware (mTLS or token).

6. Audit Logging

Domain Expert: Observability Engineer

Log all API calls (method, params, user, outcome).

Store logs in:

Windows Event Log (Application channel), and/or

Local JSON log file with rotation.

Include both API request and PowerShell output.

Deliverables:

Logging module.

Sample audit record.

7. Deployment & Operations

Domain Expert: Windows Systems Administrator

Package Node.js app + config.

Deploy to both DHCP servers.

Register service via nssm install or sc.exe.

Configure firewall (allow inbound 8443 local/management subnet only).

Deliverables:

Deployment runbook.

install-service.ps1 script.

8. Testing Strategy

Domain Expert: QA Engineer

Unit test: API returns correct JSON, error codes, validation.

Integration test: Add reservation → verify in DHCP console.

Negative test: bad IP, bad MAC, duplicate reservation, no permissions.

Performance: simulate 50 concurrent requests.

Deliverables:

Postman collection for manual testing.

Basic automated test script.

9. Future Enhancements

Add a UI dashboard (simple React/HTML frontend).

Central controller that can call both agents → single pane of glass.

Bulk import/export (CSV → multiple reservations).

Extend beyond reservations: scopes, leases, server options.

📋 Development Workflow with Sub-Agents

Systems Architect — finalize architecture & service wrapper.

API Designer — draft OpenAPI spec + JSON schema.

PowerShell SME — build helper module & test commands.

Security Engineer — add validation + TLS.

Identity Specialist — wire up auth (start simple, iterate).

Observability Engineer — implement structured logging.

SysAdmin — package & deploy to DHCP servers.

QA Engineer — run Postman & unit tests.

Parallel streams: API spec, PowerShell module, and validation can all progress simultaneously. Claude Code sub-agents can take each domain task independently.