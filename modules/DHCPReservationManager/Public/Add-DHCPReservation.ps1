<#
.SYNOPSIS
    Create a new DHCP reservation

.DESCRIPTION
    Adds a new IPv4 reservation to the specified DHCP scope

.PARAMETER ScopeId
    The DHCP scope ID

.PARAMETER IPAddress
    The IP address to reserve

.PARAMETER ClientId
    The client MAC address

.PARAMETER Name
    Optional hostname or device name

.PARAMETER Description
    Optional description

.EXAMPLE
    .\Add-DHCPReservation.ps1 -ScopeId 192.168.1.0 -IPAddress 192.168.1.100 -ClientId AA-BB-CC-DD-EE-FF -Name "Server01"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$')]
    [string]$ScopeId,

    [Parameter(Mandatory=$true)]
    [ValidatePattern('^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$')]
    [string]$IPAddress,

    [Parameter(Mandatory=$true)]
    [ValidatePattern('^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$')]
    [string]$ClientId,

    [Parameter(Mandatory=$false)]
    [ValidateLength(0,255)]
    [string]$Name,

    [Parameter(Mandatory=$false)]
    [ValidateLength(0,500)]
    [string]$Description
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

    # Build parameters
    $params = @{
        ScopeId = $ScopeId
        IPAddress = $IPAddress
        ClientId = $normalizedClientId
    }

    if ($Name) { $params.Name = $Name }
    if ($Description) { $params.Description = $Description }

    # Create reservation
    Add-DhcpServerv4Reservation @params -ErrorAction Stop

    # Retrieve the created reservation to return full details
    $reservation = Get-DhcpServerv4Reservation -ScopeId $ScopeId -ClientId $normalizedClientId -ErrorAction Stop

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

    if ($errorMessage -match 'already exists') {
        $response = ConvertTo-StandardResponse -Success $false -ErrorType 'DuplicateReservation' `
            -Message "A reservation already exists for IP $IPAddress or MAC $ClientId" `
            -Category 'ResourceExists'
    }
    elseif ($errorMessage -match 'outside|range') {
        $response = ConvertTo-StandardResponse -Success $false -ErrorType 'InvalidRange' `
            -Message "IP address $IPAddress is outside the scope range" `
            -Category 'InvalidArgument'
    }
    elseif ($errorMessage -match 'does not exist') {
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
        -Message 'Insufficient permissions to create DHCP reservation' `
        -Category 'PermissionDenied'

    $response | ConvertTo-Json -Depth 10 -Compress
}
catch {
    $response = ConvertTo-StandardResponse -Success $false -ErrorType 'UnexpectedError' `
        -Message $_.Exception.Message `
        -Category $_.CategoryInfo.Category.ToString()

    $response | ConvertTo-Json -Depth 10 -Compress
}