<#
.SYNOPSIS
    Uninstall DHCP REST Agent Windows Service

.DESCRIPTION
    Stops and removes the Windows Service

.EXAMPLE
    .\uninstall-service.ps1
#>

[CmdletBinding()]
param(
    [string]$ServiceName = "DHCPRestAgent"
)

$ErrorActionPreference = 'Stop'

# Require administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Write-Host "Uninstalling DHCP REST Agent service..." -ForegroundColor Cyan

# Check if service exists
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if (-not $service) {
    Write-Host "Service '$ServiceName' not found" -ForegroundColor Yellow
    exit 0
}

# Stop service if running
if ($service.Status -eq 'Running') {
    Write-Host "Stopping service..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 2
}

# Remove service
Write-Host "Removing service..." -ForegroundColor Green

$nssmPath = Get-Command nssm.exe -ErrorAction SilentlyContinue

if ($nssmPath) {
    & nssm remove $ServiceName confirm
} else {
    # Fallback to sc.exe
    & sc.exe delete $ServiceName
}

Start-Sleep -Seconds 2

# Verify removal
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($service) {
    Write-Host "Failed to remove service" -ForegroundColor Red
} else {
    Write-Host "Service uninstalled successfully!" -ForegroundColor Green
}

# Remove firewall rule
Write-Host "`nRemoving firewall rule..." -ForegroundColor Cyan

$firewallRule = Get-NetFirewallRule -DisplayName "DHCP REST Agent" -ErrorAction SilentlyContinue

if ($firewallRule) {
    Remove-NetFirewallRule -DisplayName "DHCP REST Agent"
    Write-Host "Firewall rule removed" -ForegroundColor Green
} else {
    Write-Host "Firewall rule not found" -ForegroundColor Yellow
}

Write-Host "`nUninstallation complete!" -ForegroundColor Green