# DHCP REST Agent - API Reference

Complete API reference for the DHCP REST Agent.

## Base URL

- **Development**: `http://localhost:8443`
- **Production**: `https://your-server:8443`

## Authentication

All endpoints (except `/health`) require authentication when enabled.

### Bearer Token

```http
Authorization: Bearer YOUR_TOKEN_HERE
```

### mTLS (Optional)

Client certificate authentication can be enabled in configuration.

## Endpoints

### Health Check

#### GET /health

Get service health status and diagnostics.

**Authentication**: Not required

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2025-09-30T10:00:00.000Z",
  "version": "1.0.0",
  "checks": {
    "powershell": "available",
    "dhcp": "running",
    "disk": "OK",
    "certificates": "valid"
  }
}
```

---

### DHCP Leases

#### GET /scopes/:scopeId/leases

Get all active and inactive DHCP leases for a scope.

**Authentication**: Required (if enabled)

**Parameters**:
- `scopeId` (path, required): IPv4 scope ID (e.g., `192.168.1.0`)

**Example Request**:
```powershell
Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/leases"
```

**Example Response**:
```json
{
  "success": true,
  "data": [
    {
      "IPAddress": "192.168.1.100",
      "ClientId": "AA-BB-CC-DD-EE-FF",
      "HostName": "DESKTOP-ABC123",
      "LeaseExpiryTime": "2025-10-01T10:30:00.0000000-04:00",
      "AddressState": "Active",
      "LeaseType": "DHCP",
      "ScopeId": "192.168.1.0",
      "Description": ""
    },
    {
      "IPAddress": "192.168.1.101",
      "ClientId": "11-22-33-44-55-66",
      "HostName": "LAPTOP-XYZ789",
      "LeaseExpiryTime": "2025-10-01T11:15:00.0000000-04:00",
      "AddressState": "Active",
      "LeaseType": "DHCP",
      "ScopeId": "192.168.1.0",
      "Description": ""
    }
  ],
  "count": 2,
  "scope": "192.168.1.0"
}
```

**Address States**:
- `Active`: Lease is currently active
- `Inactive`: Lease has expired or been released
- `Offered`: Lease has been offered but not yet acknowledged

**Lease Types**:
- `DHCP`: Standard DHCP lease
- `BOOTP`: BOOTP protocol lease
- `Both`: Supports both DHCP and BOOTP

**Use Case**: List all current leases to find which devices to convert to reservations

---

### DHCP Reservations

#### GET /scopes/:scopeId/reservations

Get all DHCP reservations for a scope.

**Authentication**: Required (if enabled)

**Parameters**:
- `scopeId` (path, required): IPv4 scope ID (e.g., `192.168.1.0`)

**Example Request**:
```powershell
Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations"
```

**Example Response**:
```json
{
  "success": true,
  "data": [
    {
      "ClientId": "AA-BB-CC-DD-EE-FF",
      "Name": "PrinterServer",
      "Description": "Main office printer",
      "IPAddress": "192.168.1.50",
      "Type": "Both",
      "ScopeId": "192.168.1.0"
    }
  ],
  "count": 1,
  "scope": "192.168.1.0"
}
```

---

#### GET /scopes/:scopeId/reservations/:clientId

Get a specific DHCP reservation by MAC address.

**Authentication**: Required (if enabled)

**Parameters**:
- `scopeId` (path, required): IPv4 scope ID
- `clientId` (path, required): MAC address (supports formats: `AA-BB-CC-DD-EE-FF` or `AA:BB:CC:DD:EE:FF`)

**Example Request**:
```powershell
Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations/AA-BB-CC-DD-EE-FF"
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "ClientId": "AA-BB-CC-DD-EE-FF",
    "Name": "PrinterServer",
    "Description": "Main office printer",
    "IPAddress": "192.168.1.50",
    "Type": "Both",
    "ScopeId": "192.168.1.0"
  }
}
```

---

#### POST /scopes/:scopeId/reservations

Create a new DHCP reservation.

**Authentication**: Required (if enabled)

**Parameters**:
- `scopeId` (path, required): IPv4 scope ID

**Request Body**:
```json
{
  "ipAddress": "192.168.1.50",
  "clientId": "AA-BB-CC-DD-EE-FF",
  "name": "PrinterServer",
  "description": "Main office printer"
}
```

**Required Fields**:
- `ipAddress`: IPv4 address within the scope
- `clientId`: MAC address (will be normalized to uppercase with dashes)

**Optional Fields**:
- `name`: Friendly name for the reservation
- `description`: Additional notes

**Example Request**:
```powershell
$body = @{
    ipAddress = "192.168.1.50"
    clientId = "AA-BB-CC-DD-EE-FF"
    name = "PrinterServer"
    description = "Main office printer"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "ClientId": "AA-BB-CC-DD-EE-FF",
    "Name": "PrinterServer",
    "Description": "Main office printer",
    "IPAddress": "192.168.1.50",
    "Type": "Both",
    "ScopeId": "192.168.1.0"
  },
  "message": "Reservation created successfully"
}
```

---

#### PUT /scopes/:scopeId/reservations/:clientId

Update an existing DHCP reservation.

**Authentication**: Required (if enabled)

**Parameters**:
- `scopeId` (path, required): IPv4 scope ID
- `clientId` (path, required): MAC address

**Request Body** (all fields optional):
```json
{
  "name": "UpdatedName",
  "description": "Updated description"
}
```

**Note**: IP address and MAC address cannot be changed. To change these, delete and recreate the reservation.

**Example Request**:
```powershell
$body = @{
    name = "NewPrinterServer"
    description = "Moved to new office"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations/AA-BB-CC-DD-EE-FF" `
    -Method Put `
    -ContentType "application/json" `
    -Body $body
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "ClientId": "AA-BB-CC-DD-EE-FF",
    "Name": "NewPrinterServer",
    "Description": "Moved to new office",
    "IPAddress": "192.168.1.50",
    "Type": "Both",
    "ScopeId": "192.168.1.0"
  },
  "message": "Reservation updated successfully"
}
```

---

#### DELETE /scopes/:scopeId/reservations/:clientId

Delete a DHCP reservation.

**Authentication**: Required (if enabled)

**Parameters**:
- `scopeId` (path, required): IPv4 scope ID
- `clientId` (path, required): MAC address

**Idempotency**: This operation is idempotent. Deleting a non-existent reservation returns success.

**Example Request**:
```powershell
Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations/AA-BB-CC-DD-EE-FF" `
    -Method Delete
```

**Response**: HTTP 204 No Content

---

## Common Workflows

### Convert a Lease to a Reservation

1. **List all leases** to find the device:
```powershell
$leases = Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/leases"
$lease = $leases.data | Where-Object { $_.HostName -eq "DESKTOP-ABC123" }
```

2. **Create a reservation** using the lease information:
```powershell
$body = @{
    ipAddress = $lease.IPAddress
    clientId = $lease.ClientId
    name = $lease.HostName
    description = "Converted from dynamic lease"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body
```

### Bulk Import Reservations

```powershell
$reservations = @(
    @{ ipAddress = "192.168.1.50"; clientId = "AA-BB-CC-DD-EE-FF"; name = "Device1" },
    @{ ipAddress = "192.168.1.51"; clientId = "11-22-33-44-55-66"; name = "Device2" }
)

foreach ($r in $reservations) {
    $body = $r | ConvertTo-Json
    Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body
    Start-Sleep -Milliseconds 200  # Rate limiting
}
```

### Update Multiple Reservations

```powershell
$reservations = Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations"

foreach ($r in $reservations.data) {
    if ($r.Name -like "Old*") {
        $body = @{ description = "Updated $(Get-Date -Format 'yyyy-MM-dd')" } | ConvertTo-Json
        Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations/$($r.ClientId)" `
            -Method Put `
            -ContentType "application/json" `
            -Body $body
    }
}
```

---

## Error Responses

All error responses follow this format:

```json
{
  "success": false,
  "error": "Error message",
  "details": [
    {
      "field": "ipAddress",
      "message": "IP address is required"
    }
  ]
}
```

### Common HTTP Status Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200 | OK | Successful GET/PUT request |
| 201 | Created | Successful POST request |
| 204 | No Content | Successful DELETE request |
| 400 | Bad Request | Invalid input (validation error) |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Scope or reservation doesn't exist |
| 409 | Conflict | Reservation already exists |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server-side error |

---

## Rate Limits

- **Global**: 100 requests/minute per IP
- **Write Operations** (POST/PUT/DELETE): 50 requests/minute per IP

When rate limited, the API returns HTTP 429 with:
```json
{
  "success": false,
  "error": "Too many requests from this IP, please try again later"
}
```

---

## Data Formats

### MAC Address

Accepted formats:
- `AA-BB-CC-DD-EE-FF` (preferred)
- `AA:BB:CC:DD:EE:FF`
- `aa-bb-cc-dd-ee-ff` (converted to uppercase)

Returned format: `AA-BB-CC-DD-EE-FF`

### IPv4 Address

Format: `xxx.xxx.xxx.xxx` (e.g., `192.168.1.50`)

### Timestamps

Format: ISO 8601 with timezone (e.g., `2025-10-01T10:30:00.0000000-04:00`)

---

## PowerShell Examples

### Using with Authentication

```powershell
$headers = @{
    "Authorization" = "Bearer your-token-here"
}

Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/leases" `
    -Headers $headers
```

### Error Handling

```powershell
try {
    $result = Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body
    Write-Host "Success: $($result.message)"
} catch {
    $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "Error: $($errorDetails.error)"
    if ($errorDetails.details) {
        $errorDetails.details | ForEach-Object {
            Write-Host "  - $($_.field): $($_.message)"
        }
    }
}
```

---

## Further Reading

- [README.md](README.md) - Full documentation
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [QUICKSTART.md](QUICKSTART.md) - Quick setup guide
