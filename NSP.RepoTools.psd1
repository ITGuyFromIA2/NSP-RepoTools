@{
    RootModule = 'NSP.RepoTools.psm1'
    ModuleVersion = '0.1.1'
    GUID = '3b984d0b-ad51-4cb6-bbfd-421cd22bcf85'
    Author = 'Network Systems Plus'
    CompanyName = 'Network Systems Plus'
    Copyright = '(c) 2026 Network Systems Plus. All rights reserved.'
    Description = 'Maintainer tools for NSP repositories: a sweep for client references (names, tenants, addresses, e-mail, paths) in tracked files, untracked files, and Git history, and the checked release routine to the PowerShell Gallery.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Add-NSPClientToken'
        'Find-NSPClientReference'
        'Get-NSPClientToken'
        'Get-NSPClientTokenPath'
        'Publish-NSPModule'
        'Remove-NSPClientToken'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Git', 'Privacy', 'Repository', 'Publishing', 'NSP')
            ProjectUri = 'https://github.com/ITGuyFromIA2/NSP-RepoTools'
            LicenseUri = 'https://github.com/ITGuyFromIA2/NSP-RepoTools/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/ITGuyFromIA2/NSP-RepoTools/blob/main/CHANGELOG.md'
        }
    }
}
