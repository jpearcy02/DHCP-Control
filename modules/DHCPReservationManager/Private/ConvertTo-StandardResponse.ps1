function ConvertTo-StandardResponse {
    <#
    .SYNOPSIS
        Converts operation results to standardized JSON response format

    .DESCRIPTION
        Creates a consistent response structure for all DHCP operations
        Handles both success and error cases
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [object]$Data,

        [Parameter(Mandatory=$false)]
        [bool]$Success = $true,

        [Parameter(Mandatory=$false)]
        [string]$ErrorType,

        [Parameter(Mandatory=$false)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [string]$Category
    )

    $response = @{
        success = $Success
        timestamp = (Get-Date).ToString('o')
    }

    if ($Success) {
        $response.data = $Data
    } else {
        $response.errorType = $ErrorType
        $response.message = $Message
        if ($Category) {
            $response.category = $Category
        }
    }

    return $response
}