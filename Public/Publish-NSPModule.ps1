function Publish-NSPModule {
    <#
    .SYNOPSIS
        Checks, packages, and publishes an NSP module repository to the PowerShell Gallery.
    .DESCRIPTION
        The release routine shared by every NSP module repository (it replaces each repo's own
        tools\Publish-ToGallery.ps1). Every check runs before anything is published:

        1. Manifest: exactly one module manifest at the root; Test-ModuleManifest passes; when a
           Public\ folder exists, FunctionsToExport lists exactly its files.
        2. Changelog: CHANGELOG.md (when present) has a heading for this version that is not
           marked unreleased.
        3. Git: no uncommitted or untracked files, so the package is exactly a commit.
        4. Version: higher than the newest version already in the repository.
        5. Client references: Find-NSPClientReference over tracked and untracked files and all of
           history, with your client token list (an empty list fails: only patterns would run).
           Prints locations and rules only.
        6. The repository's own tools\Test-Repo.ps1, in a separate process; it must exit 0.
        7. Package: tracked files only (ignored client data can never ship), without the
           developer files (Tests\, tools\, dot files, CLAUDE.md, PLAN.md, analyzer settings),
           staged under the module's name. The staged manifest must pass Test-ModuleManifest and
           import under Windows PowerShell 5.1.

        Then, after confirmation, Publish-PSResource (Microsoft.PowerShell.PSResourceGet) with the
        API key from Get-NSPSecret (NSP.Bootstrap), a check that the version is really live, and a
        local annotated tag v<version> (not pushed; -NoTag skips it).

        -WhatIf runs every check and the staging, lists the package, and publishes nothing.

        A tracked .nsp-repotools.psd1 can adjust the package:
            @{ Publish = @{ Exclude = @('Legacy/*', 'docs/*'); Include = @() } }
        Exclude adds wildcards on the repo-relative path (forward slashes). Include, when set,
        limits the package to those top-level files and folders.
    .EXAMPLE
        Publish-NSPModule -Path . -WhatIf
    .EXAMPLE
        Publish-NSPModule -Path C:\GitRepo\NSP-PoSHToolkits\NSP-Console
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive release routine: progress is for the person publishing.')]
    param(
        [string]$Path = '.',
        [string]$Repository = 'PSGallery',
        [string]$SecretName = 'MS.PSGallery.ApiKey',
        [string[]]$TokenPath = @(Get-NSPClientTokenPath),
        [switch]$NoTag
    )

    $ErrorActionPreference = 'Stop'
    $root = (Invoke-NSPGit -RepoRoot (Resolve-Path -LiteralPath $Path).ProviderPath -Arguments 'rev-parse', '--show-toplevel' | Select-Object -First 1)
    if (-not $root) { throw "$Path is not inside a Git repository." }
    $root = $root.Replace('/', '\')
    $config = Get-NSPPublishConfig -RepoRoot $root
    $failures = [System.Collections.Generic.List[string]]::new()
    $step = { param([string]$Name) Write-Host "`n=== $Name ===" -ForegroundColor Cyan }
    $fail = { param([string]$Message) $failures.Add($Message); Write-Host "  $Message" -ForegroundColor Red }
    $pass = { param([string]$Message) Write-Host "  $Message" -ForegroundColor Green }

    # 1. Manifest
    & $step 'Manifest'
    $manifests = @(Get-ChildItem -LiteralPath $root -Filter '*.psd1' -File | Where-Object { $_.Name -ne 'PSScriptAnalyzerSettings.psd1' -and -not $_.Name.StartsWith('.') } |
            Where-Object { (Import-PowerShellDataFile -LiteralPath $_.FullName).ContainsKey('ModuleVersion') })
    if ($manifests.Count -ne 1) { throw "Expected one module manifest at $root, found $($manifests.Count)." }
    $manifestFile = $manifests[0]
    $name = $manifestFile.BaseName
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestFile.FullName
    $version = [version]$manifest.ModuleVersion
    $null = Test-ModuleManifest -Path $manifestFile.FullName
    & $pass "$name $version"
    $publicFolder = Join-Path $root 'Public'
    if (Test-Path -LiteralPath $publicFolder) {
        $public = @(Get-ChildItem -LiteralPath $publicFolder -Filter '*.ps1' -File -Recurse | ForEach-Object { $_.BaseName } | Sort-Object)
        $exported = @($manifest.FunctionsToExport | Sort-Object)
        if ($exported -contains '*') { & $fail 'FunctionsToExport is a wildcard: list the Public\ functions.' }
        elseif (@(Compare-Object $public $exported).Count) { & $fail "FunctionsToExport does not match Public\: $(@(Compare-Object $public $exported | ForEach-Object { '{0}{1}' -f $(if ($_.SideIndicator -eq '<=') { 'not exported: ' } else { 'no file: ' }), $_.InputObject }) -join '; ')" }
        else { & $pass "FunctionsToExport matches Public\ ($($public.Count))" }
    }

    # 2. Changelog
    $changelog = Join-Path $root 'CHANGELOG.md'
    if (Test-Path -LiteralPath $changelog) {
        $heading = @(Get-Content -LiteralPath $changelog | Where-Object { $_ -match ('^#+\s.*(?<![\d.])' + [regex]::Escape([string]$version) + '(?![\d.])') }) | Select-Object -First 1
        if (-not $heading) { & $fail "CHANGELOG.md has no heading for $version." }
        elseif ($heading -match '(?i)unreleased') { & $fail "CHANGELOG.md still marks $version unreleased: $heading" }
        else { & $pass "CHANGELOG.md: $heading" }
    }

    # 3. Git
    & $step 'Git'
    $dirty = @(Invoke-NSPGit -RepoRoot $root -Arguments 'status', '--porcelain' | Where-Object { $_ })
    if ($dirty.Count) { & $fail "$($dirty.Count) uncommitted or untracked file(s): commit or ignore them first." }
    $commit = Invoke-NSPGit -RepoRoot $root -Arguments 'rev-parse', '--short', 'HEAD' | Select-Object -First 1
    $tagName = "v$version"
    if (@(Invoke-NSPGit -RepoRoot $root -Arguments 'tag', '--list', $tagName | Where-Object { $_ }).Count) {
        & $fail "Tag $tagName already exists: was $version released already?"
    }
    if (-not $dirty.Count) { & $pass "clean at $commit" }

    # 4. Version
    & $step "Version on $Repository"
    try {
        $published = Get-NSPPublishedVersion -Name $name -Repository $Repository
        if ($published -and $published -ge $version) { & $fail "$Repository already has $name $published; raise ModuleVersion above it." }
        elseif ($published) { & $pass "$Repository has $published; publishing $version" }
        else { & $pass "$name is not on $Repository yet" }
    } catch {
        if ($WhatIfPreference) { Write-Warning "Could not check $Repository ($_). A real run stops here." }
        else { & $fail "Could not check $Repository`: $_" }
    }

    if ($failures.Count) { throw "Not published. Fix first:`n- $($failures -join "`n- ")" }

    # 5. Client references, history included. Locations and rules only.
    & $step 'Client references (working tree, untracked, history)'
    if (-not @(Get-NSPClientToken -Path $TokenPath).Count) {
        & $fail "Your client token list is empty ($($TokenPath -join ', ')): only the pattern rules would run. Add tokens with Add-NSPClientToken."
    } else {
        $hits = @(Find-NSPClientReference -Path $root -TokenPath $TokenPath -IncludeUntracked -History -WarningAction SilentlyContinue)
        if ($hits.Count) {
            foreach ($hit in $hits) { & $fail "$($hit.Scope) $($hit.File):$($hit.Line)$(if ($hit.Commit) { " @$($hit.Commit)" }) [$($hit.Rule)]" }
            Write-Host '  Review with: Find-NSPClientReference -Path . -IncludeUntracked -History' -ForegroundColor Red
        } else { & $pass 'clean' }
    }

    # 6. The repository's own checks
    $testRepo = Join-Path $root 'tools\Test-Repo.ps1'
    if (Test-Path -LiteralPath $testRepo) {
        & $step 'tools\Test-Repo.ps1'
        $hostExe = (Get-Process -Id $PID).Path
        & $hostExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $testRepo | Out-Host
        if ($LASTEXITCODE -ne 0) { & $fail "tools\Test-Repo.ps1 failed (exit code $LASTEXITCODE)." }
    } else {
        Write-Warning 'No tools\Test-Repo.ps1: only the checks above ran.'
    }

    if ($failures.Count) { throw "Not published. Fix first:`n- $($failures -join "`n- ")" }

    # 7. Package: tracked files only, staged under the module's name.
    & $step 'Package'
    $files = @(Get-NSPPublishFile -RepoRoot $root -Config $config)
    if ($files -notcontains $manifestFile.Name) { throw "The package would not include $($manifestFile.Name): check Publish.Include and Publish.Exclude." }
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    $stageRoot = Join-Path $tempBase ('NSPPublish_' + [guid]::NewGuid().ToString('N'))
    $stage = Join-Path $stageRoot $name
    $result = [pscustomobject]@{ Name = $name; Version = $version; Repository = $Repository; Commit = $commit; Files = $files; Published = $false; Tag = $null }
    try {
        foreach ($file in $files) {
            $target = Join-Path $stage $file
            $null = New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force -WhatIf:$false -Confirm:$false
            Copy-Item -LiteralPath (Join-Path $root $file) -Destination $target -WhatIf:$false -Confirm:$false
        }
        $top = @($files | ForEach-Object { ($_ -split '/')[0] } | Select-Object -Unique)
        & $pass "$($files.Count) files: $($top -join ', ')"
        $null = Test-ModuleManifest -Path (Join-Path $stage $manifestFile.Name)
        $windowsPowerShell = Get-Command 'powershell.exe' -ErrorAction SilentlyContinue
        if ($windowsPowerShell) {
            $stagedManifest = Join-Path $stage $manifestFile.Name
            & $windowsPowerShell.Source -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "`$ErrorActionPreference='Stop'; Import-Module '$stagedManifest' -Force" 2>&1 | Out-Host
            if ($LASTEXITCODE -ne 0) { throw 'The staged package does not import under Windows PowerShell 5.1: a file it needs is missing from the package.' }
            & $pass 'package imports under Windows PowerShell 5.1'
        }

        if ($PSCmdlet.ShouldProcess("$name $version from $commit -> $Repository", 'Publish')) {
            & $step "Publish to $Repository"
            Invoke-NSPPublishResource -Path $stage -Repository $Repository -SecretName $SecretName
            $live = $null
            foreach ($attempt in 1..6) {
                Start-Sleep -Seconds 10
                try { $live = Get-NSPPublishedVersion -Name $name -Repository $Repository } catch { $live = $null }
                if ($live -ge $version) { break }
            }
            if ($live -ge $version) {
                $result.Published = $true
                & $pass "$name $version is live on $Repository."
            } else {
                throw "Publish-PSResource reported success, but $Repository does not list $name $version yet. Check before publishing again: it may be indexing lag."
            }
            if (-not $NoTag) {
                Invoke-NSPGit -RepoRoot $root -Arguments '-c', 'tag.gpgsign=false', 'tag', '-a', $tagName, '-m', "$name $version" | Out-Null
                $result.Tag = $tagName
                & $pass "Tagged $tagName at $commit (local). Push it with: git push origin $tagName"
            }
        }
    } finally {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force -WhatIf:$false -Confirm:$false -ErrorAction SilentlyContinue
    }
    $result
}
