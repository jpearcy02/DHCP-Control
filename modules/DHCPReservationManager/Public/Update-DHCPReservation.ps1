<#
.SYNOPSIS
    Update an existing DHCP reservation

.DESCRIPTION
    Modifies an existing IPv4 reservation in the DHCP scope
    Can update Name, Description, or IP Address

.PARAMETER ScopeId
    The DHCP scope ID

.PARAMETER ClientId
    The client MAC address

.PARAMETER IPAddress
    New IP address (optional)

.PARAMETER Name
    New hostname/device name (optional)

.PARAMETER Description
    New description (optional)

.EXAMPLE
    .\Update-DHCPReservation.ps1 -ScopeId 192.168.1.0 -ClientId AA-BB-CC-DD-EE-FF -Name "NewName"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$')]
    [string]$ScopeId,

    [Parameter(Mandatory=$true)]
    [ValidatePattern('^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$')]
    [string]$ClientId,

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$')]
    [string]$IPAddress,

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

    # Verify reservation exists
    $existing = Get-DhcpServerv4Reservation -ScopeId $ScopeId -ClientId $normalizedClientId -ErrorAction Stop

    # Build parameters for Set cmdlet
    $params = @{
        ScopeId = $ScopeId
        ClientId = $normalizedClientId
    }

    if ($IPAddress) { $params.IPAddress = $IPAddress }
    if ($PSBoundParameters.ContainsKey('Name')) { $params.Name = $Name }
    if ($PSBoundParameters.ContainsKey('Description')) { $params.Description = $Description }

    # Update reservation
    Set-DhcpServerv4Reservation @params -ErrorAction Stop

    # Retrieve updated reservation
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

    if ($errorMessage -match 'Cannot find|does not exist') {
        $response = ConvertTo-StandardResponse -Success $false -ErrorType 'NotFound' `
            -Message "Reservation not found: $ClientId in scope $ScopeId" `
            -Category 'ResourceNotFound'
    }
    elseif ($errorMessage -match 'already exists') {
        $response = ConvertTo-StandardResponse -Success $false -ErrorType 'DuplicateReservation' `
            -Message "Cannot update: IP address conflict with existing reservation" `
            -Category 'ResourceExists'
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
        -Message 'Insufficient permissions to update DHCP reservation' `
        -Category 'PermissionDenied'

    $response | ConvertTo-Json -Depth 10 -Compress
}
catch {
    $response = ConvertTo-StandardResponse -Success $false -ErrorType 'UnexpectedError' `
        -Message $_.Exception.Message `
        -Category $_.CategoryInfo.Category.ToString()

    $response | ConvertTo-Json -Depth 10 -Compress
}