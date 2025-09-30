<#
.SYNOPSIS
    Generate self-signed TLS certificates for testing

.DESCRIPTION
    Creates self-signed certificates for HTTPS server and optionally client certificates for mTLS
    WARNING: For testing only! Use proper CA-signed certificates in production.

.EXAMPLE
    .\generate-test-certs.ps1
#>

[CmdletBinding()]
param(
    [string]$CertPath = "..\certs",
    [string]$ServerName = "localhost",
    [int]$ValidityDays = 365
)

$ErrorActionPreference = 'Stop'

Write-Host "Generating test TLS certificates..." -ForegroundColor Cyan
Write-Host "WARNING: These are self-signed certificates for testing only!" -ForegroundColor Yellow

# Create certs directory if it doesn't exist
$certDir = Join-Path $PSScriptRoot $CertPath
if (-not (Test-Path $certDir)) {
    New-Item -ItemType Directory -Path $certDir -Force | Out-Null
}

# Generate server certificate
Write-Host "`nGenerating server certificate..." -ForegroundColor Green

$serverCert = New-SelfSignedCertificate `
    -Subject "CN=$ServerName" `
    -DnsName $ServerName, "127.0.0.1", "::1" `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddDays($ValidityDays) `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyUsage DigitalSignature, KeyEncipherment `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1") `
    -FriendlyName "DHCP REST Agent Server Certificate"

# Export server certificate
$serverCertPath = Join-Path $certDir "server.crt"
$serverKeyPath = Join-Path $certDir "server.key"
$serverPfxPath = Join-Path $certDir "server.pfx"

# Export to PFX (includes private key)
$pfxPassword = ConvertTo-SecureString -String "password" -Force -AsPlainText
Export-PfxCertificate -Cert $serverCert -FilePath $serverPfxPath -Password $pfxPassword | Out-Null

# Export certificate (public key)
Export-Certificate -Cert $serverCert -FilePath $serverCertPath -Type CERT | Out-Null

Write-Host "Server certificate created: $serverCertPath" -ForegroundColor Green
Write-Host "Server PFX created: $serverPfxPath (password: password)" -ForegroundColor Green

# For Node.js, we need to extract the private key from PFX
# Using OpenSSL if available, otherwise provide instructions
$opensslPath = Get-Command openssl.exe -ErrorAction SilentlyContinue

if ($opensslPath) {
    Write-Host "`nExtracting private key..." -ForegroundColor Green

    # Convert PFX to PEM with private key
    $env:OPENSSL_CONF = ""
    & openssl pkcs12 -in $serverPfxPath -nocerts -out $serverKeyPath -nodes -passin pass:password 2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Server private key created: $serverKeyPath" -ForegroundColor Green
    } else {
        Write-Host "Failed to extract private key. Install OpenSSL or extract manually." -ForegroundColor Yellow
    }
} else {
    Write-Host "`nOpenSSL not found. To extract private key:" -ForegroundColor Yellow
    Write-Host "1. Install OpenSSL: choco install openssl" -ForegroundColor Yellow
    Write-Host "2. Run: openssl pkcs12 -in $serverPfxPath -nocerts -out $serverKeyPath -nodes -passin pass:password" -ForegroundColor Yellow
}

# Generate CA certificate for mTLS (optional)
Write-Host "`nGenerating CA certificate for mTLS..." -ForegroundColor Green

$caCert = New-SelfSignedCertificate `
    -Subject "CN=DHCP REST Agent CA" `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddDays($ValidityDays) `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyUsage CertSign, CRLSign, DigitalSignature `
    -TextExtension @("2.5.29.19={text}CA=true") `
    -FriendlyName "DHCP REST Agent CA"

$caCertPath = Join-Path $certDir "ca.crt"
Export-Certificate -Cert $caCert -FilePath $caCertPath -Type CERT | Out-Null

Write-Host "CA certificate created: $caCertPath" -ForegroundColor Green

# Generate client certificate (for mTLS testing)
Write-Host "`nGenerating client certificate..." -ForegroundColor Green

$clientCert = New-SelfSignedCertificate `
    -Subject "CN=DHCP API Client" `
    -Signer $caCert `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddDays($ValidityDays) `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyUsage DigitalSignature, KeyEncipherment `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2") `
    -FriendlyName "DHCP REST Agent Client Certificate"

$clientCertPath = Join-Path $certDir "client.crt"
$clientPfxPath = Join-Path $certDir "client.pfx"

Export-Certificate -Cert $clientCert -FilePath $clientCertPath -Type CERT | Out-Null
Export-PfxCertificate -Cert $clientCert -FilePath $clientPfxPath -Password $pfxPassword | Out-Null

Write-Host "Client certificate created: $clientCertPath" -ForegroundColor Green
Write-Host "Client PFX created: $clientPfxPath (password: password)" -ForegroundColor Green

# Trust the certificates (for testing)
Write-Host "`nInstalling certificates to Trusted Root..." -ForegroundColor Cyan

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
$store.Open("ReadWrite")
$store.Add($caCert)
$store.Close()

Write-Host "Certificates installed successfully!" -ForegroundColor Green

# Summary
Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "Certificate Generation Complete" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "`nFiles created in: $certDir" -ForegroundColor White
Write-Host "- server.crt (Server certificate)" -ForegroundColor White
Write-Host "- server.key (Server private key)" -ForegroundColor White
Write-Host "- server.pfx (Server PFX)" -ForegroundColor White
Write-Host "- ca.crt (CA certificate)" -ForegroundColor White
Write-Host "- client.crt (Client certificate)" -ForegroundColor White
Write-Host "- client.pfx (Client PFX)" -ForegroundColor White
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Update config/default.json with certificate paths" -ForegroundColor White
Write-Host "2. For mTLS, set 'requireClientCert: true' in config" -ForegroundColor White
Write-Host "3. Start the server: npm start" -ForegroundColor White
Write-Host "`nReminder: These are TEST certificates only!" -ForegroundColor Yellow