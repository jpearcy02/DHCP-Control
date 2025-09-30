function Format-MacAddress {
    <#
    .SYNOPSIS
        Normalizes MAC address format

    .DESCRIPTION
        Converts MAC address to standard format (uppercase with dashes)
        Handles both colon and dash separators
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$MacAddress
    )

    # Remove all separators and convert to uppercase
    $normalized = $MacAddress.Replace(':', '').Replace('-', '').ToUpper()

    # Validate length
    if ($normalized.Length -ne 12) {
        throw "Invalid MAC address length: $MacAddress"
    }

    # Validate hex characters
    if ($normalized -notmatch '^[0-9A-F]{12}$') {
        throw "Invalid MAC address format: $MacAddress"
    }

    # Format with dashes
    $formatted = $normalized -replace '(.{2})(?=.)', '$1-'

    return $formatted
}