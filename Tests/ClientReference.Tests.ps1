# Each test plants references in a throwaway Git repository under TestDrive. Every planted value
# is invented: the "client" is Acme Widgets on acme-widgets.test-like names that are not reserved,
# because reserved names are exactly what the sweep must ignore.
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\NSP.RepoTools.psd1') -Force

    function Invoke-TestGit {
        param([string]$Repo, [string[]]$GitArgument)
        & git -C $Repo -c user.name=Test -c user.email=test@example.test -c commit.gpgsign=false @GitArgument 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git $GitArgument failed" }
    }

    function Initialize-TestRepo {
        $repo = Join-Path $TestDrive ([guid]::NewGuid().Guid.Substring(0, 8))
        New-Item -ItemType Directory -Path $repo | Out-Null
        Invoke-TestGit -Repo $repo -GitArgument 'init', '--quiet'
        $repo
    }

    function Write-TestFile([string]$Repo, [string]$Name, [string]$Content) {
        $file = Join-Path $Repo $Name
        $folder = Split-Path -Parent $file
        if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
        [IO.File]::WriteAllText($file, $Content)
    }

    $script:tokenFile = Join-Path $TestDrive 'tokens.csv'
    @(
        [pscustomobject]@{ Token = 'Acme Widgets'; Source = 'client name' }
        [pscustomobject]@{ Token = 'acmewidgets'; Source = 'tenant' }
        [pscustomobject]@{ Token = 'ATES'; Source = 'client abbreviation' }
    ) | Export-Csv -LiteralPath $script:tokenFile -NoTypeInformation
}

Describe 'Find-NSPClientReference: working tree' {
    BeforeAll {
        $script:repo = Initialize-TestRepo
        Write-TestFile -Repo $repo -Name 'README.md' -Content (@(
                'Built for Acme Widgets.'
                'Contact jane.doe@acmewidgets.com or user@contoso.example or someone@sub.example.com.'
                'Tenant acmewidgets.onmicrosoft.com; sample contoso.onmicrosoft.com.'
                'Share \\fs01\finance and \\server\share.'
                'Profile C:\Users\jdoe\Desktop and C:\Users\Public\Desktop.'
                'Addresses 52.10.20.30, 10.0.0.1, 192.0.2.10, 8.8.8.8, version 5.1.22621.4391.'
                'Updates and dates are fine; @odata.type is not mail.'
            ) -join "`n")
        Write-TestFile -Repo $repo -Name 'Legacy\old.txt' -Content 'Acme Widgets legacy export'
        Write-TestFile -Repo $repo -Name 'certs\client.pfx' -Content 'not really a key'
        [IO.File]::WriteAllBytes((Join-Path $repo 'shot.png'), [byte[]](0x89, 0x50, 0x00, 0x01))
        Write-TestFile -Repo $repo -Name '.nsp-repotools.psd1' -Content "@{ ClientSweep = @{ ExcludePath = @('Legacy/*'); Allow = @('jane.doe@acmewidgets.com') } }"
        Invoke-TestGit -Repo $repo -GitArgument 'add', '-A'
        Invoke-TestGit -Repo $repo -GitArgument 'commit', '--quiet', '-m', 'Initial'
        Write-TestFile -Repo $repo -Name 'notes-acmewidgets.txt' -Content 'untracked'
        $script:hits = @(Find-NSPClientReference -Path $repo -TokenPath $tokenFile)
        $script:withUntracked = @(Find-NSPClientReference -Path $repo -TokenPath $tokenFile -IncludeUntracked)
    }

    It 'finds client tokens as whole words, ignoring case' {
        @($hits | Where-Object { $_.Rule -eq 'ClientToken' -and $_.File -eq 'README.md' } | ForEach-Object Match) | Should -Contain 'Acme Widgets'
        @($hits | Where-Object { $_.Rule -eq 'ClientToken' -and $_.Match -eq 'ATES' }).Count | Should -Be 0 -Because '"updates" contains "ates" but not as a word'
    }

    It 'reports pattern findings and skips reserved, private, and placeholder values' {
        $rules = @($hits | Where-Object File -EQ 'README.md' | Where-Object Rule -NE 'ClientToken' | ForEach-Object { "$($_.Rule)=$($_.Match)" })
        $rules | Should -Contain 'TenantName=acmewidgets.onmicrosoft.com'
        $rules | Should -Contain 'UncPath=\\fs01\finance'
        $rules | Should -Contain 'UserProfilePath=C:\Users\jdoe'
        $rules | Should -Contain 'PublicIPv4=52.10.20.30'
        ($rules -join ' ') | Should -Not -Match 'contoso|example|\\\\server\\|Users\\Public|=10\.0\.0\.1|192\.0\.2|8\.8\.8\.8|odata|22621'
    }

    It 'honors the repository allow list and excluded paths' {
        @($hits | Where-Object Match -EQ 'jane.doe@acmewidgets.com').Count | Should -Be 0
        @($hits | Where-Object File -Like 'Legacy/*').Count | Should -Be 0
    }

    It 'flags key files and binary files by path' {
        @($hits | Where-Object Rule -EQ 'KeyOrCertificateFile' | ForEach-Object File) | Should -Contain 'certs/client.pfx'
        @($hits | Where-Object Rule -EQ 'Unscanned' | ForEach-Object File) | Should -Contain 'shot.png'
    }

    It 'checks untracked files only with -IncludeUntracked, path included' {
        @($hits | Where-Object Scope -EQ 'Untracked').Count | Should -Be 0
        $untracked = @($withUntracked | Where-Object Scope -EQ 'Untracked')
        $untracked.File | Should -Contain 'notes-acmewidgets.txt'
        $untracked[0].Line | Should -Be 0
    }

    It 'takes extra tokens from -Token and warns when there are none' {
        $extra = @(Find-NSPClientReference -Path $repo -TokenPath (Join-Path $TestDrive 'none.csv') -Token 'finance' -WarningAction SilentlyContinue)
        @($extra | Where-Object { $_.Rule -eq 'ClientToken' -and $_.Source -eq 'parameter' }).Count | Should -BeGreaterThan 0
        $null = Find-NSPClientReference -Path $repo -TokenPath (Join-Path $TestDrive 'none.csv') -WarningVariable warned -WarningAction SilentlyContinue
        $warned | Should -Not -BeNullOrEmpty
    }
}

Describe 'Find-NSPClientReference: history' {
    BeforeAll {
        $script:repo = Initialize-TestRepo
        Write-TestFile -Repo $repo -Name 'config.txt' -Content "first line`nserver for Acme Widgets"
        Invoke-TestGit -Repo $repo -GitArgument 'add', '-A'
        Invoke-TestGit -Repo $repo -GitArgument 'commit', '--quiet', '-m', 'Add config'
        Write-TestFile -Repo $repo -Name 'config.txt' -Content "first line`nserver for a client"
        Invoke-TestGit -Repo $repo -GitArgument 'add', '-A'
        Invoke-TestGit -Repo $repo -GitArgument 'commit', '--quiet', '-m', "Scrub`n`nRemoved the ATES name"
        [IO.File]::WriteAllText((Join-Path $repo 'export.xml'), "<Policies>`r`n  <Name>Acme Widgets travel</Name>`r`n</Policies>", [System.Text.Encoding]::Unicode)
        Invoke-TestGit -Repo $repo -GitArgument 'add', '-A'
        Invoke-TestGit -Repo $repo -GitArgument 'commit', '--quiet', '-m', 'Add export'
        Invoke-TestGit -Repo $repo -GitArgument 'rm', '--quiet', 'config.txt', 'export.xml'
        Invoke-TestGit -Repo $repo -GitArgument 'commit', '--quiet', '-m', 'Remove config'
        $script:hits = @(Find-NSPClientReference -Path $repo -TokenPath $tokenFile -History)
    }

    It 'finds a reference that only survives in history, with its line and commit' {
        $hit = @($hits | Where-Object { $_.Scope -eq 'History' -and $_.Match -eq 'Acme Widgets' -and $_.File -eq 'config.txt' })
        $hit.Count | Should -Be 1
        $hit[0].File | Should -Be 'config.txt'
        $hit[0].Line | Should -Be 2
        $hit[0].Commit | Should -Match '^[0-9a-f]{7}$'
        @($hits | Where-Object Scope -EQ 'WorkingTree').Count | Should -Be 0
    }

    It 'reads a UTF-16 file that Git treats as binary' {
        $hit = @($hits | Where-Object { $_.File -eq 'export.xml' })
        $hit.Rule | Should -Be 'ClientToken'
        $hit[0].Line | Should -Be 2
    }

    It 'searches commit messages' {
        $message = @($hits | Where-Object Scope -EQ 'CommitMessage')
        $message.Match | Should -Contain 'ATES'
        $message[0].Line | Should -Be 3
    }
}

Describe 'Client token list' {
    It 'resolves the per-user path, with an override' {
        $saved = $env:NSP_CLIENT_TOKENS
        try {
            $env:NSP_CLIENT_TOKENS = ''
            Get-NSPClientTokenPath | Should -BeLike '*NSP\RepoTools\ClientTokens.csv'
            $env:NSP_CLIENT_TOKENS = 'X:\elsewhere.csv'
            Get-NSPClientTokenPath | Should -Be 'X:\elsewhere.csv'
        } finally { $env:NSP_CLIENT_TOKENS = $saved }
    }

    It 'adds tokens with organization labels, skips short and excluded ones, and de-duplicates' {
        $path = Join-Path $TestDrive 'add.csv'
        $first = Add-NSPClientToken -Token 'Acme Widgets', 'acme-widgets.com', 'abc', 'NSP-BASE-01' -Source 'test' -ExcludePattern '^NSP-' -Path $path
        $first.Added | Should -Be 3
        $tokens = @(Get-NSPClientToken -Path $path | ForEach-Object Token)
        $tokens | Should -HaveCount 3
        foreach ($t in 'Acme Widgets', 'acme-widgets', 'acme-widgets.com') { $tokens | Should -Contain $t }
        (Add-NSPClientToken -Token 'ACME WIDGETS' -Path $path).Added | Should -Be 0
    }

    It 'harvests named properties and e-mail addresses from JSON, skipping excluded properties' {
        $json = Join-Path $TestDrive 'inventory.json'
        @{
            TenantId = '11111111-2222-3333-4444-555555555555'
            Groups = @(@{ displayName = 'Acme Finance'; id = 'aaaaaaaa-0000-0000-0000-000000000001' })
            Notes = 'owner: ops@acmewidgets.net'
            Owner = 'ops@acmewidgets.net'
            Travel = @{ Ids = @('bbbbbbbb-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000003') }
            RoleTemplates = @(@{ displayName = 'Global Administrator' })
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $json
        $path = Join-Path $TestDrive 'harvest.csv'
        $null = Add-NSPClientToken -FromJson $json -Property 'displayName', 'id', 'TenantId', 'Ids' -ExcludeProperty 'RoleTemplates' -Path $path
        $tokens = @(Get-NSPClientToken -Path $path | ForEach-Object Token)
        $tokens | Should -Contain 'Acme Finance'
        $tokens | Should -Contain '11111111-2222-3333-4444-555555555555'
        $tokens | Should -Contain 'ops@acmewidgets.net'
        $tokens | Should -Contain 'acmewidgets'
        $tokens | Should -Contain 'bbbbbbbb-0000-0000-0000-000000000003'
        $tokens | Should -Not -Contain 'Global Administrator'
    }

    It 'removes tokens by value or pattern, ignoring case' {
        $path = Join-Path $TestDrive 'remove.csv'
        $null = Add-NSPClientToken -Token 'Acme Widgets', 'admin', 'Group-Sales', 'Group-Finance' -Path $path
        $result = Remove-NSPClientToken -Token 'ADMIN' -Pattern '^Group-' -Path $path
        $result.Removed | Should -Be 3
        @(Get-NSPClientToken -Path $path | ForEach-Object Token) | Should -Be @('Acme Widgets')
    }

    It 'reads plain text lists with comments' {
        $path = Join-Path $TestDrive 'plain.txt'
        Set-Content -LiteralPath $path -Value '# clients', 'Acme Widgets', '', 'acme widgets', 'Globex'
        @(Get-NSPClientToken -Path $path | ForEach-Object Token) | Should -Be @('Acme Widgets', 'Globex')
    }
}
