@{
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'
    Author = 'DHCP REST Agent'
    CompanyName = ''
    Copyright = '(c) 2025. All rights reserved.'
    Description = 'PowerShell module for managing DHCP reservations via REST API'

    PowerShellVersion = '5.1'

    RequiredModules = @('DhcpServer')

    FunctionsToExport = @(
        'Get-DHCPReservations',
        'Get-DHCPReservation',
        'Get-DHCPLeases',
        'Add-DHCPReservation',
        'Update-DHCPReservation',
        'Remove-DHCPReservation'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @('DHCP', 'Windows', 'Network', 'REST', 'API')
            ProjectUri = ''
            LicenseUri = ''
            ReleaseNotes = 'Initial release'
        }
    }
}