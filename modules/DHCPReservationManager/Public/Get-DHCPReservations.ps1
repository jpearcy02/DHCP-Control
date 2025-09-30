<#
.SYNOPSIS
    Get all DHCP reservations in a scope

.DESCRIPTION
    Retrieves all IPv4 reservations in the specified DHCP scope
    Returns standardized JSON response

.PARAMETER ScopeId
    The DHCP scope ID (e.g., 192.168.1.0)

.EXAMPLE
    .\Get-DHCPReservations.ps1 -ScopeId 192.168.1.0
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
. (Join-Path $privatePath 'Test-DhcpCmdletAvailable.ps1')

try {
    $ErrorActionPreference = 'Stop'

    # Verify DHCP cmdlets are available
    if (-not (Test-DhcpCmdletAvailable)) {
        throw "DHCP PowerShell cmdlets are not available"
    }

    # Get all reservations in the scope
    $reservations = Get-DhcpServerv4Reservation -ScopeId $ScopeId -ErrorAction Stop

    # Convert to consistent format
    $result = @()
    foreach ($reservation in $reservations) {
        $result += @{
            ScopeId = $reservation.ScopeId.IPAddressToString
            IPAddress = $reservation.IPAddress.IPAddressToString
            ClientId = $reservation.ClientId
            Name = $reservation.Name
            Description = $reservation.Description
            Type = $reservation.Type.ToString()
        }
    }

    # Return success response
    $response = ConvertTo-StandardResponse -Data $result -Success $true
    $response | ConvertTo-Json -Depth 10 -Compress
}
catch [Microsoft.Management.Infrastructure.CimException] {
    # DHCP-specific errors
    $errorMessage = $_.Exception.Message

    if ($errorMessage -match 'does not exist') {
        $response = ConvertTo-StandardResponse -Success $false -ErrorType 'NotFound' `
            -Message "DHCP scope $ScopeId does not exist" `
            -Category 'ResourceNotFound'
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
        -Message 'Insufficient permissions to access DHCP server' `
        -Category 'PermissionDenied'

    $response | ConvertTo-Json -Depth 10 -Compress
}
catch {
    $response = ConvertTo-StandardResponse -Success $false -ErrorType 'UnexpectedError' `
        -Message $_.Exception.Message `
        -Category $_.CategoryInfo.Category.ToString()

    $response | ConvertTo-Json -Depth 10 -Compress
}