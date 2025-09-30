<#
.SYNOPSIS
    Remove a DHCP reservation

.DESCRIPTION
    Deletes an IPv4 reservation from the DHCP scope
    Idempotent operation - returns success even if reservation doesn't exist

.PARAMETER ScopeId
    The DHCP scope ID

.PARAMETER ClientId
    The client MAC address

.EXAMPLE
    .\Remove-DHCPReservation.ps1 -ScopeId 192.168.1.0 -ClientId AA-BB-CC-DD-EE-FF
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$')]
    [string]$ScopeId,

    [Parameter(Mandatory=$true)]
    [ValidatePattern('^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$')]
    [string]$ClientId
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

    # Normalize MAC address
    $normalizedClientId = Format-MacAddress -MacAddress $ClientId

    # Remove reservation
    Remove-DhcpServerv4Reservation -ScopeId $ScopeId -ClientId $normalizedClientId -ErrorAction Stop

    $result = @{
        deleted = $true
        scopeId = $ScopeId
        clientId = $normalizedClientId
    }

    $response = ConvertTo-StandardResponse -Data $result -Success $true
    $response | ConvertTo-Json -Depth 10 -Compress
}
catch [Microsoft.Management.Infrastructure.CimException] {
    $errorMessage = $_.Exception.Message

    # Idempotent behavior - if not found, still return success
    if ($errorMessage -match 'Cannot find|does not exist|Failed to get reservation') {
        $result = @{
            deleted = $false
            scopeId = $ScopeId
            clientId = $normalizedClientId
            note = "Reservation not found (already deleted)"
        }

        $response = ConvertTo-StandardResponse -Data $result -Success $true
        $response | ConvertTo-Json -Depth 10 -Compress
    }
    else {
        $response = ConvertTo-StandardResponse -Success $false -ErrorType 'DhcpError' `
            -Message $errorMessage `
            -Category 'DhcpOperationFailed'

        $response | ConvertTo-Json -Depth 10 -Compress
    }
}
catch [System.UnauthorizedAccessException] {
    $response = ConvertTo-StandardResponse -Success $false -ErrorType 'PermissionDenied' `
        -Message 'Insufficient permissions to remove DHCP reservation' `
        -Category 'PermissionDenied'

    $response | ConvertTo-Json -Depth 10 -Compress
}
catch {
    $response = ConvertTo-StandardResponse -Success $false -ErrorType 'UnexpectedError' `
        -Message $_.Exception.Message `
        -Category $_.CategoryInfo.Category.ToString()

    $response | ConvertTo-Json -Depth 10 -Compress
}