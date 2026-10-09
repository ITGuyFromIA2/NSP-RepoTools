# Each test builds a throwaway module repository under TestDrive. The Gallery lookup and the
# publish call are mocked: nothing here reaches a repository or reads a secret.
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\NSP.RepoTools.psd1') -Force

    function Invoke-TestGit {
        param([string]$Repo, [string[]]$GitArgument)
        & git -C $Repo -c user.name=Test -c user.email=test@example.test -c commit.gpgsign=false -c tag.gpgsign=false @GitArgument 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git $GitArgument failed" }
    }

    function Write-TestFile([string]$Repo, [string]$Name, [string]$Content) {
        $file = Join-Path $Repo $Name
        $folder = Split-Path -Parent $file
        if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
        [IO.File]::WriteAllText($file, $Content)
    }

    # A small module repository that passes every check; -Change edits it before the commit.
    function Initialize-TestModuleRepo {
        param([scriptblock]$Change, [int]$TestExitCode = 0)
        $repo = Join-Path $TestDrive ([guid]::NewGuid().Guid.Substring(0, 8))
        New-Item -ItemType Directory -Path $repo | Out-Null
        Invoke-TestGit -Repo $repo -GitArgument 'init', '--quiet'
        Write-TestFile -Repo $repo -Name 'Fake.Module.psd1' -Content "@{ RootModule = 'Fake.Module.psm1'; ModuleVersion = '1.2.0'; GUID = '11111111-2222-3333-4444-555555555555'; Author = 'Test'; Description = 'Test module'; FunctionsToExport = @('Get-FakeThing') }"
        Write-TestFile -Repo $repo -Name 'Fake.Module.psm1' -Content 'foreach ($f in Get-ChildItem (Join-Path $PSScriptRoot ''Public'') -Filter *.ps1) { . $f.FullName }'
        Write-TestFile -Repo $repo -Name 'Public\Get-FakeThing.ps1' -Content 'function Get-FakeThing { ''thing'' }'
        Write-TestFile -Repo $repo -Name 'README.md' -Content '# Fake.Module'
        Write-TestFile -Repo $repo -Name 'CHANGELOG.md' -Content "# Changelog`n`n## 1.2.0`n`n- Things."
        Write-TestFile -Repo $repo -Name 'Tests\Fake.Tests.ps1' -Content '# tests'
        Write-TestFile -Repo $repo -Name 'tools\Test-Repo.ps1' -Content "exit $TestExitCode"
        Write-TestFile -Repo $repo -Name 'CLAUDE.md' -Content '# notes'
        Write-TestFile -Repo $repo -Name '.gitignore' -Content 'Config/Local/'
        Write-TestFile -Repo $repo -Name 'Config\Local\tenant.json' -Content '{ "TenantDomain": "anything" }'
        if ($Change) { & $Change $repo }
        Invoke-TestGit -Repo $repo -GitArgument 'add', '-A'
        Invoke-TestGit -Repo $repo -GitArgument 'commit', '--quiet', '-m', 'Module'
        $repo
    }

    $script:tokenFile = Join-Path $TestDrive 'tokens.csv'
    [pscustomobject]@{ Token = 'Acme Widgets'; Source = 'client name' } | Export-Csv -LiteralPath $script:tokenFile -NoTypeInformation
}

Describe 'Publish-NSPModule' {
    BeforeEach {
        Mock -ModuleName NSP.RepoTools Write-Host { }
        Mock -ModuleName NSP.RepoTools Out-Host { }
        Mock -ModuleName NSP.RepoTools Start-Sleep { }
        Mock -ModuleName NSP.RepoTools Get-NSPPublishedVersion { [version]'1.1.0' }
        Mock -ModuleName NSP.RepoTools Invoke-NSPPublishResource { }
    }

    It '-WhatIf runs the checks, stages tracked runtime files only, and publishes nothing' {
        $repo = Initialize-TestModuleRepo
        $result = Publish-NSPModule -Path $repo -TokenPath $tokenFile -WhatIf
        $result.Name | Should -Be 'Fake.Module'
        $result.Version | Should -Be ([version]'1.2.0')
        $result.Published | Should -BeFalse
        @($result.Files | Sort-Object) | Should -Be @('CHANGELOG.md', 'Fake.Module.psd1', 'Fake.Module.psm1', 'Public/Get-FakeThing.ps1', 'README.md')
        Should -Invoke -ModuleName NSP.RepoTools Invoke-NSPPublishResource -Times 0
        @(git -C $repo tag --list).Count | Should -Be 0
    }

    It 'publishes the staged folder under the module name, confirms it is live, and tags the commit' {
        $script:lookups = 0
        Mock -ModuleName NSP.RepoTools Get-NSPPublishedVersion { $script:lookups++; if ($script:lookups -eq 1) { [version]'1.1.0' } else { [version]'1.2.0' } }
        $repo = Initialize-TestModuleRepo
        $result = Publish-NSPModule -Path $repo -TokenPath $tokenFile -Confirm:$false
        $result.Published | Should -BeTrue
        $result.Tag | Should -Be 'v1.2.0'
        Should -Invoke -ModuleName NSP.RepoTools Invoke-NSPPublishResource -Times 1 -ParameterFilter { (Split-Path -Leaf $Path) -eq 'Fake.Module' -and $Repository -eq 'PSGallery' }
        @(git -C $repo tag --list) | Should -Contain 'v1.2.0'
    }

    It 'stops when the version is not live after publishing' {
        $repo = Initialize-TestModuleRepo
        { Publish-NSPModule -Path $repo -TokenPath $tokenFile -Confirm:$false } | Should -Throw '*does not list Fake.Module 1.2.0*'
        @(git -C $repo tag --list).Count | Should -Be 0
    }

    It 'honors Publish.Exclude in .nsp-repotools.psd1' {
        $repo = Initialize-TestModuleRepo -Change { param($r) Write-TestFile -Repo $r -Name '.nsp-repotools.psd1' -Content "@{ Publish = @{ Exclude = @('docs/*') } }"; Write-TestFile -Repo $r -Name 'docs\notes.md' -Content 'notes' }
        @((Publish-NSPModule -Path $repo -TokenPath $tokenFile -WhatIf).Files) | Should -Not -Contain 'docs/notes.md'
    }

    It 'refuses: <Case>' -ForEach @(
        @{ Case = 'exports that do not match Public\'; Expected = '*FunctionsToExport does not match*'; Change = { param($r) Write-TestFile -Repo $r -Name 'Public\Get-Other.ps1' -Content 'function Get-Other { }' } }
        @{ Case = 'a changelog without this version'; Expected = '*no heading for 1.2.0*'; Change = { param($r) Write-TestFile -Repo $r -Name 'CHANGELOG.md' -Content "## 1.1.0`n" } }
        @{ Case = 'a version still marked unreleased'; Expected = '*marks 1.2.0 unreleased*'; Change = { param($r) Write-TestFile -Repo $r -Name 'CHANGELOG.md' -Content "## 1.2.0 (unreleased)`n" } }
        @{ Case = 'a client reference that only survives in history'; Expected = '*History README.md:2*ClientToken*'; Change = {
                param($r)
                Write-TestFile -Repo $r -Name 'README.md' -Content "# Fake.Module`nBuilt for Acme Widgets."
                Invoke-TestGit -Repo $r -GitArgument 'add', '-A'
                Invoke-TestGit -Repo $r -GitArgument 'commit', '--quiet', '-m', 'First'
                Write-TestFile -Repo $r -Name 'README.md' -Content '# Fake.Module'
            } }
    ) {
        $repo = Initialize-TestModuleRepo -Change $Change
        { Publish-NSPModule -Path $repo -TokenPath $tokenFile -WhatIf } | Should -Throw $Expected
        Should -Invoke -ModuleName NSP.RepoTools Invoke-NSPPublishResource -Times 0
    }

    It 'refuses uncommitted changes' {
        $repo = Initialize-TestModuleRepo
        Write-TestFile -Repo $repo -Name 'README.md' -Content 'edited'
        { Publish-NSPModule -Path $repo -TokenPath $tokenFile -WhatIf } | Should -Throw '*uncommitted or untracked*'
    }

    It 'refuses a version the repository already has' {
        Mock -ModuleName NSP.RepoTools Get-NSPPublishedVersion { [version]'1.2.0' }
        { Publish-NSPModule -Path (Initialize-TestModuleRepo) -TokenPath $tokenFile -WhatIf } | Should -Throw '*already has Fake.Module 1.2.0*'
    }

    It 'refuses a version that is already tagged' {
        $repo = Initialize-TestModuleRepo
        Invoke-TestGit -Repo $repo -GitArgument 'tag', 'v1.2.0'
        { Publish-NSPModule -Path $repo -TokenPath $tokenFile -WhatIf } | Should -Throw '*Tag v1.2.0 already exists*'
    }

    It 'refuses an empty client token list' {
        { Publish-NSPModule -Path (Initialize-TestModuleRepo) -TokenPath (Join-Path $TestDrive 'none.csv') -WhatIf } | Should -Throw '*token list is empty*'
    }

    It 'refuses when tools\Test-Repo.ps1 fails' {
        { Publish-NSPModule -Path (Initialize-TestModuleRepo -TestExitCode 1) -TokenPath $tokenFile -WhatIf } | Should -Throw '*Test-Repo.ps1 failed*'
    }
}
