@{
    RootModule = 'NSP.RepoTools.psm1'
    ModuleVersion = '0.1.0'
    GUID = '3b984d0b-ad51-4cb6-bbfd-421cd22bcf85'
    Author = 'Network Systems Plus'
    CompanyName = 'Network Systems Plus'
    Copyright = '(c) 2026 Network Systems Plus. All rights reserved.'
    Description = 'Maintainer tools for NSP repositories: a sweep for client references (names, tenants, addresses, e-mail, paths) in tracked files, untracked files, and Git history.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Add-NSPClientToken'
        'Find-NSPClientReference'
        'Get-NSPClientToken'
        'Get-NSPClientTokenPath'
        'Remove-NSPClientToken'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Git', 'Privacy', 'Repository', 'NSP')
            ReleaseNotes = 'Initial module: Find-NSPClientReference and a per-user client token list.'
        }
    }
}
