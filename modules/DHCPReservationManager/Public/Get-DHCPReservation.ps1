<#
.SYNOPSIS
    Get a specific DHCP reservation by MAC address

.DESCRIPTION
    Retrieves a single IPv4 reservation by client ID (MAC address)

.PARAMETER ScopeId
    The DHCP scope ID

.PARAMETER ClientId
    The client MAC address (e.g., AA-BB-CC-DD-EE-FF)

.EXAMPLE
    .\Get-DHCPReservation.ps1 -ScopeId 192.168.1.0 -ClientId AA-BB-CC-DD-EE-FF
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

    # Get specific reservation
    $reservation = Get-DhcpServerv4Reservation -ScopeId $ScopeId -ClientId $normalizedClientId -ErrorAction Stop

    # Convert to consistent format
    $result = @{
        ScopeId = $reservation.ScopeId.IPAddressToString
        IPAddress = $reservation.IPAddress.IPAddressToString
        ClientId = $reservation.ClientId
        Name = $reservation.Name
        Description = $reservation.Description
        Type = $reservation.Type.ToString()
    }

    $response = ConvertTo-StandardResponse -Data $result -Success $true
    $response | ConvertTo-Json -Depth 10 -Compress
}
catch [Microsoft.Management.Infrastructure.CimException] {
    $errorMessage = $_.Exception.Message

    if ($errorMessage -match 'Cannot find|does not exist') {
        $response = ConvertTo-StandardResponse -Success $false -ErrorType 'NotFound' `
            -Message "Reservation not found: $ClientId in scope $ScopeId" `
            -Category 'ResourceNotFound'
    }
    else {
        $response = ConvertTo-StandardResponse -Success $false -ErrorType 'DhcpError' `
            -Message $errorMessage `
            -Category 'DhcpOperationFailed'
    }

    $response | ConvertTo-Json -Depth 10 -Compress
}
catch {
    $response = ConvertTo-StandardResponse -Success $false -ErrorType 'UnexpectedError' `
        -Message $_.Exception.Message `
        -Category $_.CategoryInfo.Category.ToString()

    $response | ConvertTo-Json -Depth 10 -Compress
}