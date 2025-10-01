# Troubleshooting Guide

This guide covers common issues encountered during deployment and operation of the DHCP REST Agent.

## Table of Contents
- [Installation Issues](#installation-issues)
- [API Errors](#api-errors)
- [PowerShell Errors](#powershell-errors)
- [Configuration Issues](#configuration-issues)
- [Service Issues](#service-issues)

## Installation Issues

### Missing Dependencies

**Problem:** `npm install` fails or modules are missing

**Solution:**
```powershell
# Clear npm cache and reinstall
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

### Node.js Version

**Problem:** Application won't start or shows syntax errors

**Solution:** Ensure you're running Node.js 18 or later:
```powershell
node --version  # Should be v18.x.x or higher
```

## API Errors

### Authentication Required (401)

**Problem:** API returns `{"success":false,"error":"Authorization header required"}`

**Cause:** Authentication is enabled but no token provided, or `config/local.json` changes weren't loaded

**Solution:**

Option 1 - Disable authentication for development (in `config/local.json`):
```json
{
  "security": {
    "authentication": {
      "required": false
    }
  }
}
```

Option 2 - Use bearer token:
```powershell
$headers = @{ "Authorization" = "Bearer your-token-here" }
Invoke-RestMethod -Uri "http://localhost:8443/scopes/..." -Headers $headers
```

**Important:** After changing `config/local.json`, restart the server:
- If using `npm run dev`: Type `rs` and press Enter
- If running as service: `Restart-Service DHCPRestAgent`

### TLS Certificate Not Found

**Problem:**
```
Failed to create HTTPS server
ENOENT: no such file or directory, open 'c:\DHCP Control\certs\server.crt'
```

**Cause:** TLS is enabled but certificates don't exist

**Solution:**

Option 1 - Disable TLS for development (in `config/local.json`):
```json
{
  "tls": {
    "enabled": false
  }
}
```

Option 2 - Generate test certificates:
```powershell
.\scripts\generate-test-certs.ps1
```

### Invalid Parameter Format (400)

**Problem:** `{"success":false,"error":"Invalid parameter format"}`

**Cause:** This was a bug in earlier versions where PowerShell parameters were wrapped in extra quotes

**Solution:** Ensure you have the latest version with the fix in `src/services/powershell.js`:
- Simple values (IP addresses, MAC addresses) are passed without quotes
- Only values containing spaces or special characters are quoted

**Fixed in commit:** 6690884 - "Fix PowerShell parameter escaping and config merge"

### Reservation Already Exists (409)

**Problem:** `{"success":false,"error":"Reservation already exists"}`

**Cause:** A reservation with that MAC address or IP already exists in the scope

**Solution:**

Option 1 - Delete the existing reservation first:
```powershell
Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations/AA-BB-CC-DD-EE-FF" -Method Delete
```

Option 2 - Update the existing reservation instead:
```powershell
$body = @{ name = "NewName"; description = "Updated" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:8443/scopes/192.168.1.0/reservations/AA-BB-CC-DD-EE-FF" -Method Put -Body $body -ContentType "application/json"
```

### Delete Returns 409 Conflict

**Problem:** DELETE operations return 409 instead of 204 No Content

**Cause:** Bug in earlier versions where "Failed to get reservation" error wasn't handled as idempotent delete

**Solution:** Update `modules/DHCPReservationManager/Public/Remove-DHCPReservation.ps1` to include:
```powershell
if ($errorMessage -match 'Cannot find|does not exist|Failed to get reservation') {
    # Return success for idempotent behavior
}
```

**Fixed in commit:** 6690884 - "Fix PowerShell parameter escaping and config merge"

## PowerShell Errors

### DHCP Cmdlets Not Available

**Problem:** `"DHCP PowerShell cmdlets are not available"`

**Cause:** DHCP Server PowerShell module is not installed

**Solution:**
```powershell
# Install DHCP Server role (includes PowerShell module)
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Verify module is available
Get-Module -ListAvailable DhcpServer
```

### Insufficient Permissions

**Problem:** `"Insufficient permissions to perform DHCP operation"`

**Cause:** The user account running the Node.js process doesn't have DHCP administrative rights

**Solution:**

Option 1 - Run as DHCP Administrator:
```powershell
# Add user to DHCP Administrators group
Add-LocalGroupMember -Group "DHCP Administrators" -Member "DOMAIN\Username"
```

Option 2 - Run service as a service account with DHCP admin rights

### Execution Policy Blocked

**Problem:** PowerShell scripts won't execute

**Cause:** PowerShell execution policy is too restrictive

**Solution:**
```powershell
# Check current policy
Get-ExecutionPolicy

# Set to RemoteSigned (recommended)
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine

# Or bypass for testing (not recommended for production)
Set-ExecutionPolicy Bypass -Scope Process
```

### Parameter Validation Error

**Problem:**
```
The argument "'10.13.8.0'" does not match the "^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$" pattern
```

**Cause:** Bug in earlier versions where parameters were wrapped in extra single quotes

**Solution:** This was fixed in commit 6690884. Ensure `src/services/powershell.js` only adds quotes when necessary:
```javascript
// Only quote if value contains spaces or special characters
if (strValue.includes(' ') || strValue.includes('$') || strValue.includes('`')) {
    const escaped = strValue.replace(/'/g, "''");
    return `-${key} '${escaped}'`;
}
// Simple values like IP addresses don't need quoting
return `-${key} ${strValue}`;
```

## Configuration Issues

### Local Config Not Loading

**Problem:** Changes to `config/local.json` don't take effect

**Cause:** Server wasn't restarted after config changes, or deep merge bug in earlier versions

**Solution:**

1. **Ensure proper restart:**
   - Development: Type `rs` in nodemon console
   - Production: `Restart-Service DHCPRestAgent`

2. **Check config merge (fixed in commit 6690884):**

Ensure `src/utils/config.js` has the correct deep merge function:
```javascript
const deepMerge = (target, ...sources) => {
  if (!sources.length) return target;
  const source = sources.shift();

  if (source) {
    Object.keys(source).forEach((key) => {
      if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
        if (!target[key]) target[key] = {};
        target[key] = deepMerge(Object.assign({}, target[key]), source[key]);
      } else {
        target[key] = source[key];
      }
    });
  }

  return deepMerge(target, ...sources);
};
```

### Environment Variables Not Working

**Problem:** `.env` file settings don't apply

**Cause:** File not in root directory or syntax errors

**Solution:**
```powershell
# Ensure .env is in project root
ls .env

# Check syntax (no spaces around =)
# CORRECT:
AUTH_TOKEN=your-token-here

# INCORRECT:
AUTH_TOKEN = your-token-here
```

## Service Issues

### Service Won't Start

**Problem:** Windows Service fails to start or crashes immediately

**Solution:**

1. Check event logs:
```powershell
Get-EventLog -LogName Application -Source DHCPRestAgent -Newest 10
```

2. Check service configuration:
```powershell
Get-Service DHCPRestAgent | Format-List *
```

3. Test manually first:
```powershell
cd "c:\DHCP Control"
npm start
# Watch for errors
```

4. Check log files:
```powershell
Get-Content "c:\DHCP Control\logs\error-*.log" -Tail 50
```

### Service Crashes After Reboot

**Problem:** Service starts but crashes after system reboot

**Cause:** Dependencies not available or paths incorrect

**Solution:**

1. Ensure service starts after DHCP Server service:
```powershell
sc.exe config DHCPRestAgent depend= DHCPServer
```

2. Use absolute paths in service configuration

3. Check service account has network logon rights

### Port Already in Use

**Problem:** `Error: listen EADDRINUSE: address already in use :::8443`

**Cause:** Another process is using port 8443

**Solution:**

Option 1 - Find and stop conflicting process:
```powershell
# Find process using port 8443
Get-NetTCPConnection -LocalPort 8443 | Select-Object OwningProcess
Get-Process -Id <ProcessId>

# Stop it
Stop-Process -Id <ProcessId>
```

Option 2 - Change port in `config/local.json`:
```json
{
  "service": {
    "port": 8444
  }
}
```

## Performance Issues

### Slow API Responses

**Problem:** API takes several seconds to respond

**Cause:** PowerShell process spawning overhead is inherent to this architecture

**Expected Performance:**
- Latency: 200-500ms per request
- Throughput: 20-50 requests/second
- Concurrency: Up to 10 simultaneous requests

**Solution:**

For high-performance requirements:
1. Increase concurrent limit in `config/local.json`:
```json
{
  "powershell": {
    "maxConcurrent": 20
  }
}
```

2. Consider migrating to .NET Core with in-process PowerShell (10-100x faster)

### Memory Usage Increasing

**Problem:** Node.js process memory grows over time

**Cause:** PowerShell process pooling or memory leaks

**Solution:**

1. Monitor with:
```powershell
Get-Process -Name node | Select-Object CPU,WS
```

2. Restart service periodically or set up automatic restart:
```powershell
# Restart service daily at 3 AM
$trigger = New-ScheduledTaskTrigger -Daily -At 3am
$action = New-ScheduledTaskAction -Execute 'Restart-Service' -Argument 'DHCPRestAgent'
Register-ScheduledTask -TaskName "DHCP-Agent-Restart" -Trigger $trigger -Action $action
```

## Debugging Tips

### Enable Debug Logging

In `config/local.json`:
```json
{
  "logging": {
    "level": "debug"
  }
}
```

### Test PowerShell Scripts Directly

```powershell
cd "c:\DHCP Control\modules\DHCPReservationManager\Public"
.\Get-DHCPReservations.ps1 -ScopeId "192.168.1.0"
```

### Check Health Endpoint

```powershell
Invoke-RestMethod -Uri "http://localhost:8443/health"
```

Returns:
```json
{
  "status": "healthy",
  "timestamp": "2025-09-30T10:00:00.000Z",
  "version": "1.0.0",
  "checks": {
    "powershell": "available",
    "dhcp": "running",
    "disk": "OK"
  }
}
```

### View Audit Logs

```powershell
# All API activity
Get-Content "c:\DHCP Control\logs\audit-*.log" | ConvertFrom-Json | Format-Table timestamp, method, path, statusCode

# Errors only
Get-Content "c:\DHCP Control\logs\error-*.log" | ConvertFrom-Json | Format-Table timestamp, level, message
```

## Getting Help

1. **Check logs:** Always start by checking `logs/error-*.log` and `logs/audit-*.log`
2. **Test manually:** Run PowerShell scripts directly to isolate issues
3. **Check permissions:** Verify DHCP admin rights and file system permissions
4. **Review configuration:** Ensure `config/local.json` overrides are correct
5. **GitHub Issues:** Report bugs at https://github.com/jpearcy02/DHCP-Control/issues

## Common Fixes Summary

| Issue | Quick Fix |
|-------|-----------|
| Authentication error | Add `"security": {"authentication": {"required": false}}` to `config/local.json` and restart |
| TLS cert error | Add `"tls": {"enabled": false}` to `config/local.json` and restart |
| Parameter validation | Update to latest version (commit 6690884 or later) |
| Config not loading | Restart service with `rs` (dev) or `Restart-Service DHCPRestAgent` (prod) |
| Delete returns 409 | Update to latest version (commit 6690884 or later) |
| Permission denied | Add user to "DHCP Administrators" group |
| Port in use | Change port in `config/local.json` or stop conflicting process |
| DHCP cmdlets missing | Install DHCP Server role: `Install-WindowsFeature DHCP -IncludeManagementTools` |
