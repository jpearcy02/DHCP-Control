function Test-DhcpCmdletAvailable {
    <#
    .SYNOPSIS
        Tests if DHCP PowerShell cmdlets are available

    .DESCRIPTION
        Verifies that the DhcpServer module is loaded and cmdlets are accessible
    #>
    [CmdletBinding()]
    param()

    try {
        # Check if DhcpServer module is available
        $module = Get-Module -Name DhcpServer -ListAvailable

        if ($null -eq $module) {
            throw "DhcpServer PowerShell module is not installed. Please install the DHCP Server role."
        }

        # Import module if not already loaded
        if (-not (Get-Module -Name DhcpServer)) {
            Import-Module DhcpServer -ErrorAction Stop
        }

        # Test a basic cmdlet
        $null = Get-Command Get-DhcpServerv4Scope -ErrorAction Stop

        return $true
    }
    catch {
        Write-Error "DHCP PowerShell cmdlets are not available: $_"
        return $false
    }
}