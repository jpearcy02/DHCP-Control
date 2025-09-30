<#
.SYNOPSIS
    Install DHCP REST Agent as a Windows Service

.DESCRIPTION
    Installs the Node.js application as a Windows Service using nssm (Non-Sucking Service Manager)
    Configures automatic startup, restart policies, and logging

.EXAMPLE
    .\install-service.ps1
#>

[CmdletBinding()]
param(
    [string]$ServiceName = "DHCPRestAgent",
    [string]$DisplayName = "DHCP REST Agent",
    [string]$Description = "REST API for Windows DHCP Server management",
    [string]$AppPath = "",
    [string]$WorkingDirectory = ""
)

$ErrorActionPreference = 'Stop'

# Require administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Write-Host "Installing DHCP REST Agent as Windows Service..." -ForegroundColor Cyan

# Determine paths
if (-not $AppPath) {
    $scriptDir = Split-Path -Parent $PSScriptRoot
    $AppPath = Join-Path $scriptDir "src\server.js"
}

if (-not $WorkingDirectory) {
    $WorkingDirectory = Split-Path -Parent $PSScriptRoot
}

# Find Node.js
$nodePath = Get-Command node.exe -ErrorAction SilentlyContinue

if (-not $nodePath) {
    Write-Error "Node.js not found. Please install Node.js first."
    exit 1
}

Write-Host "Node.js found: $($nodePath.Source)" -ForegroundColor Green
Write-Host "Application path: $AppPath" -ForegroundColor White
Write-Host "Working directory: $WorkingDirectory" -ForegroundColor White

# Check if nssm is installed
$nssmPath = Get-Command nssm.exe -ErrorAction SilentlyContinue

if (-not $nssmPath) {
    Write-Host "nssm not found. Installing via Chocolatey..." -ForegroundColor Yellow

    # Check if Chocolatey is installed
    $chocoPath = Get-Command choco.exe -ErrorAction SilentlyContinue

    if ($chocoPath) {
        choco install nssm -y
        $nssmPath = Get-Command nssm.exe -ErrorAction SilentlyContinue
    } else {
        Write-Error "Please install nssm manually: choco install nssm"
        Write-Host "Or download from: https://nssm.cc/download" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "nssm found: $($nssmPath.Source)" -ForegroundColor Green

# Check if service already exists
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($existingService) {
    Write-Host "Service already exists. Stopping and removing..." -ForegroundColor Yellow

    if ($existingService.Status -eq 'Running') {
        Stop-Service -Name $ServiceName -Force
    }

    & nssm remove $ServiceName confirm
    Start-Sleep -Seconds 2
}

# Install service
Write-Host "`nInstalling service..." -ForegroundColor Green

& nssm install $ServiceName $nodePath.Source $AppPath

# Configure service
Write-Host "Configuring service..." -ForegroundColor Green

# Set working directory
& nssm set $ServiceName AppDirectory $WorkingDirectory

# Set environment variables
& nssm set $ServiceName AppEnvironmentExtra NODE_ENV=production

# Set display name and description
& nssm set $ServiceName DisplayName $DisplayName
& nssm set $ServiceName Description $Description

# Configure startup
& nssm set $ServiceName Start SERVICE_AUTO_START

# Configure restart policy
& nssm set $ServiceName AppThrottle 5000
& nssm set $ServiceName AppExit Default Restart
& nssm set $ServiceName AppRestartDelay 5000

# Configure graceful shutdown
& nssm set $ServiceName AppStopMethodConsole 10000
& nssm set $ServiceName AppStopMethodWindow 2000

# Configure stdout/stderr logging
$logDir = Join-Path $WorkingDirectory "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

& nssm set $ServiceName AppStdout (Join-Path $logDir "service-stdout.log")
& nssm set $ServiceName AppStderr (Join-Path $logDir "service-stderr.log")

# Rotate logs
& nssm set $ServiceName AppRotateFiles 1
& nssm set $ServiceName AppRotateOnline 1
& nssm set $ServiceName AppRotateBytes 10485760  # 10MB

Write-Host "`nService installed successfully!" -ForegroundColor Green

# Start service
Write-Host "`nStarting service..." -ForegroundColor Cyan

try {
    Start-Service -Name $ServiceName
    Start-Sleep -Seconds 3

    $service = Get-Service -Name $ServiceName

    if ($service.Status -eq 'Running') {
        Write-Host "Service started successfully!" -ForegroundColor Green
    } else {
        Write-Host "Service status: $($service.Status)" -ForegroundColor Yellow
        Write-Host "Check logs at: $logDir" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Failed to start service: $_" -ForegroundColor Red
    Write-Host "Check logs at: $logDir" -ForegroundColor Yellow
}

# Configure firewall
Write-Host "`nConfiguring firewall..." -ForegroundColor Cyan

$firewallRule = Get-NetFirewallRule -DisplayName "DHCP REST Agent" -ErrorAction SilentlyContinue

if ($firewallRule) {
    Write-Host "Firewall rule already exists" -ForegroundColor Yellow
} else {
    New-NetFirewallRule `
        -DisplayName "DHCP REST Agent" `
        -Direction Inbound `
        -LocalPort 8443 `
        -Protocol TCP `
        -Action Allow `
        -Profile Domain,Private `
        -Description "Allow inbound HTTPS traffic for DHCP REST Agent" | Out-Null

    Write-Host "Firewall rule created" -ForegroundColor Green
}

# Summary
Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "Installation Complete" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "`nService Name: $ServiceName" -ForegroundColor White
Write-Host "Status: $((Get-Service -Name $ServiceName).Status)" -ForegroundColor White
Write-Host "Startup Type: Automatic" -ForegroundColor White
Write-Host "`nUseful commands:" -ForegroundColor Cyan
Write-Host "- Start service: Start-Service $ServiceName" -ForegroundColor White
Write-Host "- Stop service: Stop-Service $ServiceName" -ForegroundColor White
Write-Host "- Restart service: Restart-Service $ServiceName" -ForegroundColor White
Write-Host "- Check status: Get-Service $ServiceName" -ForegroundColor White
Write-Host "- View logs: Get-Content '$logDir\service-stdout.log' -Tail 50" -ForegroundColor White
Write-Host "`nHealth check: https://localhost:8443/health" -ForegroundColor Cyan
Write-Host "`nTo uninstall: .\uninstall-service.ps1" -ForegroundColor Yellow