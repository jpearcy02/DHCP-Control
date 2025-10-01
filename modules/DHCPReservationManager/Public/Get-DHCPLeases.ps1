<#
.SYNOPSIS
    Get all DHCP leases for a scope

.DESCRIPTION
    Retrieves all active and inactive leases from a DHCP scope
    Returns lease information including IP, MAC, hostname, and expiration

.PARAMETER ScopeId
    The DHCP scope ID

.EXAMPLE
    .\Get-DHCPLeases.ps1 -ScopeId 192.168.1.0
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$')]
    [string]$ScopeId
)

# Import private functions
$privatePath = Join-Path $PSScriptRoot '..\Private'
. (Join-Path $privatePath 'ConvertTo-StandardResponse.ps1')
. (Join-Path $privatePath 'Format-MacAddress.ps1')
. (Join-Path $privatePath 'Test-DhcpCmdletAvailable.ps1')

try {
    $ErrorActionPreference = 'Stop'

    # Verify DHCP cmdlets
    if (-not (Test-DhcpCmdletAvailable)) {
        throw "DHCP PowerShell cmdlets are not available"
    }

    # Get all leases for the scope
    $leases = Get-DhcpServerv4Lease -ScopeId $ScopeId -ErrorAction Stop

    # Format the output
    $formattedLeases = $leases | ForEach-Object {
        # Try to format MAC address, but keep original if invalid
        $clientId = $null
        if ($_.ClientId) {
            try {
                $clientId = Format-MacAddress -MacAddress $_.ClientId
            } catch {
                # Keep original if formatting fails (invalid/incomplete MAC)
                $clientId = $_.ClientId
            }
        }

        @{
            IPAddress = $_.IPAddress.ToString()
            ClientId = $clientId
            HostName = $_.HostName
            LeaseExpiryTime = if ($_.LeaseExpiryTime) { $_.LeaseExpiryTime.ToString('o') } else { $null }
            AddressState = $_.AddressState.ToString()
            LeaseType = if ($_.Type) { $_.Type.ToString() } else { 'DHCP' }
            ScopeId = $_.ScopeId.ToString()
            Description = $_.Description
        }
    }

    $result = @{
        leases = @($formattedLeases)
        count = $formattedLeases.Count
        scopeId = $ScopeId
    }

    $response = ConvertTo-StandardResponse -Data $result -Success $true
    $response | ConvertTo-Json -Depth 10 -Compress
}
catch [Microsoft.Management.Infrastructure.CimException] {
    $errorMessage = $_.Exception.Message

    if ($errorMessage -match 'Cannot find|does not exist') {
        $response = ConvertTo-StandardResponse -Success $false -ErrorType 'NotFound' `
            -Message "Scope $ScopeId not found or has no leases" `
            -Category 'ObjectNotFound'
    }
    else {
        $response = ConvertTo-StandardResponse -Success $false -ErrorType 'DhcpError' `
            -Message $errorMessage `
            -Category 'DhcpOperationFailed'
    }

    $response | ConvertTo-Json -Depth 10 -Compress
}
catch [System.UnauthorizedAccessException] {
    $response = ConvertTo-StandardResponse -Success $false -ErrorType 'PermissionDenied' `
        -Message 'Insufficient permissions to get DHCP leases' `
        -Category 'PermissionDenied'

    $response | ConvertTo-Json -Depth 10 -Compress
}
catch {
    $response = ConvertTo-StandardResponse -Success $false -ErrorType 'UnexpectedError' `
        -Message $_.Exception.Message `
        -Category $_.CategoryInfo.Category.ToString()

    $response | ConvertTo-Json -Depth 10 -Compress
}
