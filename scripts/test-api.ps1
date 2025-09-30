<#
.SYNOPSIS
    Test DHCP REST API endpoints

.DESCRIPTION
    Quick smoke test for the DHCP REST API
    Tests health check, list, create, update, and delete operations

.EXAMPLE
    .\test-api.ps1 -Token "your-token"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$BaseUrl = "https://localhost:8443",

    [Parameter(Mandatory=$true)]
    [string]$Token,

    [Parameter(Mandatory=$false)]
    [string]$TestScopeId = "192.168.1.0",

    [Parameter(Mandatory=$false)]
    [string]$TestIP = "192.168.1.250",

    [Parameter(Mandatory=$false)]
    [string]$TestMAC = "AA-BB-CC-DD-EE-FF"
)

$ErrorActionPreference = 'Stop'

# Ignore self-signed certificate warnings
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

Write-Host "Testing DHCP REST API at $BaseUrl" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Test 1: Health Check
Write-Host "`n[1/6] Testing health check..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -SkipCertificateCheck

    if ($response.status -eq 'healthy') {
        Write-Host "✓ Health check passed" -ForegroundColor Green
        Write-Host "  Version: $($response.version)" -ForegroundColor Gray
        Write-Host "  Uptime: $([int]$response.uptime) seconds" -ForegroundColor Gray
    } else {
        Write-Host "✗ Health check unhealthy" -ForegroundColor Red
        Write-Host ($response | ConvertTo-Json) -ForegroundColor Gray
    }
}
catch {
    Write-Host "✗ Health check failed: $_" -ForegroundColor Red
}

# Test 2: List Reservations
Write-Host "`n[2/6] Testing list reservations..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/scopes/$TestScopeId/reservations" -Method Get -Headers $headers -SkipCertificateCheck

    if ($response.success) {
        Write-Host "✓ List reservations passed" -ForegroundColor Green
        Write-Host "  Count: $($response.count)" -ForegroundColor Gray
    } else {
        Write-Host "✗ List failed" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ List failed: $_" -ForegroundColor Red
}

# Test 3: Create Reservation
Write-Host "`n[3/6] Testing create reservation..." -ForegroundColor Yellow

$reservation = @{
    ipAddress = $TestIP
    clientId = $TestMAC
    name = "TestDevice"
    description = "API test reservation"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/scopes/$TestScopeId/reservations" -Method Post -Headers $headers -Body $reservation -SkipCertificateCheck

    if ($response.success) {
        Write-Host "✓ Create reservation passed" -ForegroundColor Green
        Write-Host "  IP: $($response.data.IPAddress)" -ForegroundColor Gray
        Write-Host "  MAC: $($response.data.ClientId)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Create failed" -ForegroundColor Red
    }
}
catch {
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Host "⚠ Reservation already exists (expected if running multiple times)" -ForegroundColor Yellow
    } else {
        Write-Host "✗ Create failed: $_" -ForegroundColor Red
    }
}

# Test 4: Get Specific Reservation
Write-Host "`n[4/6] Testing get specific reservation..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/scopes/$TestScopeId/reservations/$TestMAC" -Method Get -Headers $headers -SkipCertificateCheck

    if ($response.success) {
        Write-Host "✓ Get reservation passed" -ForegroundColor Green
        Write-Host "  Name: $($response.data.Name)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Get failed" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Get failed: $_" -ForegroundColor Red
}

# Test 5: Update Reservation
Write-Host "`n[5/6] Testing update reservation..." -ForegroundColor Yellow

$update = @{
    name = "UpdatedTestDevice"
    description = "Updated by API test"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/scopes/$TestScopeId/reservations/$TestMAC" -Method Put -Headers $headers -Body $update -SkipCertificateCheck

    if ($response.success) {
        Write-Host "✓ Update reservation passed" -ForegroundColor Green
        Write-Host "  New name: $($response.data.Name)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Update failed" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Update failed: $_" -ForegroundColor Red
}

# Test 6: Delete Reservation
Write-Host "`n[6/6] Testing delete reservation..." -ForegroundColor Yellow

try {
    Invoke-RestMethod -Uri "$BaseUrl/scopes/$TestScopeId/reservations/$TestMAC" -Method Delete -Headers $headers -SkipCertificateCheck | Out-Null

    Write-Host "✓ Delete reservation passed" -ForegroundColor Green
}
catch {
    if ($_.Exception.Response.StatusCode -eq 204) {
        Write-Host "✓ Delete reservation passed (204 No Content)" -ForegroundColor Green
    } else {
        Write-Host "✗ Delete failed: $_" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "API Test Complete" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan