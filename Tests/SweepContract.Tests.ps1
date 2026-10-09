# Other repositories' Test-Repo gates call the sweep (Find-NSPClientReference) and read its
# output. These tests pin that surface: changing a parameter, an output property, or a rule
# name breaks those gates, so it has to be a deliberate change made here first.
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\NSP.RepoTools.psd1') -Force

    function Get-TestParameterName([string]$Command) {
        $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        @((Get-Command $Command).Parameters.Keys | Where-Object { $common -notcontains $_ } | Sort-Object)
    }
}

Describe 'Sweep contract' {
    It 'keeps the parameters the gates use' {
        Get-TestParameterName 'Find-NSPClientReference' | Should -Be @('History', 'IncludeUntracked', 'Path', 'Token', 'TokenPath')
        Get-TestParameterName 'Get-NSPClientToken' | Should -Contain 'Path'
        Get-TestParameterName 'Add-NSPClientToken' | Should -Contain 'FromJson'
        Get-TestParameterName 'Remove-NSPClientToken' | Should -Contain 'Pattern'
        @(Get-TestParameterName 'Get-NSPClientTokenPath').Count | Should -Be 0
    }

    It 'keeps the output properties, in order' {
        $repo = Join-Path $TestDrive 'contract'
        New-Item -ItemType Directory -Path $repo | Out-Null
        & git -C $repo init --quiet
        [IO.File]::WriteAllText((Join-Path $repo 'a.txt'), 'Built for Acme Widgets.')
        & git -C $repo add -A
        $hit = @(Find-NSPClientReference -Path $repo -TokenPath (Join-Path $TestDrive 'none.csv') -Token 'Acme Widgets' -IncludeUntracked -WarningAction SilentlyContinue)[0]
        @($hit.PSObject.Properties.Name) | Should -Be @('Scope', 'File', 'Line', 'Commit', 'Rule', 'Match', 'Source')
    }

    It 'keeps the rule names' {
        $rules = InModuleScope NSP.RepoTools { @(Get-NSPClientReferenceRule | ForEach-Object Name) }
        foreach ($rule in 'Email', 'TenantName', 'UncPath', 'UserProfilePath', 'PublicIPv4', 'PrivateKey') { $rules | Should -Contain $rule }
    }
}
