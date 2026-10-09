function Find-NSPClientReference {
    <#
    .SYNOPSIS
        Sweeps a Git repository for client references before it is shared or published.
    .DESCRIPTION
        Searches the tracked files (and their paths) for:
        - ClientToken: anything in the client token list (Get-NSPClientTokenPath, or -TokenPath
          and -Token): client names, domains, tenant and object IDs, user and group names;
        - Email, TenantName (*.onmicrosoft.com), UncPath, UserProfilePath (C:\Users\<name>),
          PublicIPv4, PrivateKey: patterns that need no list. Reserved example domains
          (.example, .test, contoso.com, ...), private and documentation addresses, and
          placeholder names are not reported;
        - KeyOrCertificateFile (.pfx, .p12, .pem, .key, .cer, .crt) and Unscanned (binary files,
          such as screenshots, that could not be read as text) by path.

        -IncludeUntracked adds files Git would pick up (untracked and not ignored). -History adds
        every line ever added in any commit on any ref, and every commit message; each
        finding there is reported once, at the first commit seen. Removing a file does not remove
        it from history.

        A tracked .nsp-repotools.psd1 at the repository root can exclude paths and accept known
        text, for example the maintainer's own address:
            @{ ClientSweep = @{ ExcludePath = @('Legacy/*'); Allow = @('noreply@example.com'); AllowPattern = @() } }

        Returns one object per finding: Scope (WorkingTree, Untracked, History, CommitMessage),
        File, Line (0 for the path itself), Commit, Rule, Match, Source. A gate in a build should
        print locations and rules only, never Match or Source.
    .EXAMPLE
        Find-NSPClientReference -Path . -IncludeUntracked | Format-Table Rule, File, Line, Match
    .EXAMPLE
        Find-NSPClientReference -Path . -History | Group-Object Rule, Match | Sort-Object Count -Descending
    #>
    [CmdletBinding()]
    param(
        [string]$Path = '.',
        [string[]]$TokenPath = @(Get-NSPClientTokenPath),
        [string[]]$Token = @(),
        [switch]$IncludeUntracked,
        [switch]$History
    )

    $root = (Invoke-NSPGit -RepoRoot (Resolve-Path -LiteralPath $Path).ProviderPath -Arguments 'rev-parse', '--show-toplevel' | Select-Object -First 1)
    if (-not $root) { throw "$Path is not inside a Git repository." }
    $root = $root.Replace('/', '\')
    $config = Get-NSPRepoToolsConfig -RepoRoot $root

    $context = @{ TokenRegex = $null; TokenSource = @{}; Rules = @(Get-NSPClientReferenceRule); Allow = @{}; AllowPattern = @($config.AllowPattern) }
    foreach ($a in $config.Allow) { $context.Allow[([string]$a).ToLowerInvariant()] = $true }

    $tokens = @(Get-NSPClientToken -Path $TokenPath) + @($Token | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ Token = $_.Trim(); Source = 'parameter' } })
    foreach ($t in $tokens) {
        $key = $t.Token.ToLowerInvariant()
        if ($context.Allow.ContainsKey($key) -or $context.TokenSource.ContainsKey($key)) { continue }
        $context.TokenSource[$key] = $t.Source
    }
    if ($context.TokenSource.Count) {
        $alternatives = @($context.TokenSource.Keys | Sort-Object Length -Descending | ForEach-Object { [regex]::Escape($_) })
        $context.TokenRegex = [regex]::new('(?<![\p{L}\p{N}])(?:' + ($alternatives -join '|') + ')(?![\p{L}\p{N}])', 'IgnoreCase, CultureInvariant')
    } else {
        Write-Warning "No client tokens loaded (looked in $($TokenPath -join ', ')). Only the pattern rules run. Add tokens with Add-NSPClientToken."
    }

    $keyFile = '(?i)\.(pfx|p12|pem|key|cer|crt)$'
    $excluded = {
        param([string]$Relative)
        foreach ($pattern in $config.ExcludePath) { if ($Relative -like $pattern) { return $true } }
        $false
    }

    $scanPath = {
        param([string]$Relative, [string]$Scope, [string]$Commit)
        Find-NSPClientReferenceInLine -Context $context -Text $Relative -Scope $Scope -File $Relative -Line 0 -Commit $Commit
        if ($Relative -match $keyFile -and -not (Test-NSPClientReferenceAllowed -Context $context -Text $Relative)) {
            [pscustomobject]@{ Scope = $Scope; File = $Relative; Line = 0; Commit = $Commit; Rule = 'KeyOrCertificateFile'; Match = [IO.Path]::GetFileName($Relative); Source = 'path' }
        }
    }

    # Working tree: tracked files, and optionally what an add would pick up.
    $sets = @(@{ Scope = 'WorkingTree'; Args = @('ls-files') })
    if ($IncludeUntracked) { $sets += @{ Scope = 'Untracked'; Args = @('ls-files', '--others', '--exclude-standard') } }
    foreach ($set in $sets) {
        foreach ($relative in @(Invoke-NSPGit -RepoRoot $root -Arguments $set.Args)) {
            if (-not $relative -or (& $excluded $relative)) { continue }
            & $scanPath $relative $set.Scope $null
            $full = Join-Path $root $relative
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
            Find-NSPClientReferenceInContent -Context $context -Bytes ([IO.File]::ReadAllBytes($full)) -Scope $set.Scope -File $relative
        }
    }

    if (-not $History) { return }

    # Each history finding once: the first commit (newest first) that carries it.
    $reported = @{}
    $once = {
        process {
            $key = '{0}|{1}|{2}|{3}' -f $_.Scope, $_.File, $_.Rule, $_.Match.ToLowerInvariant()
            if (-not $reported.ContainsKey($key)) { $reported[$key] = $true; $_ }
        }
    }

    $messages = (@(Invoke-NSPGit -RepoRoot $root -Arguments 'log', '--all', '--format=%H%x1f%B%x1e') -join "`n").Split([char]0x1e)
    foreach ($entry in $messages) {
        $parts = $entry.Trim("`n", "`r").Split([char]0x1f)
        if ($parts.Count -lt 2) { continue }
        $number = 0
        foreach ($text in $parts[1].Split("`n")) {
            $number++
            Find-NSPClientReferenceInLine -Context $context -Text $text -Scope 'CommitMessage' -File '(commit message)' -Line $number -Commit $parts[0].Substring(0, 7)
        }
    }

    $state = @{ Commit = $null; File = $null; Line = 0; Skip = $false }
    Invoke-NSPGit -RepoRoot $root -Arguments 'log', '--all', '-p', '--no-color', '--no-ext-diff', '--unified=0', '--format=%x1fCOMMIT %H' | ForEach-Object {
        $text = [string]$_
        if ($text.StartsWith([string][char]0x1f + 'COMMIT ')) {
            $state.Commit = $text.Substring(8, 7); $state.File = $null; return
        }
        if ($text.StartsWith('diff --git ')) { $state.File = $null; $state.Skip = $true; return }
        if ($text.StartsWith('+++ ')) {
            $target = $text.Substring(4)
            if ($target -eq '/dev/null') { $state.Skip = $true; return }
            $state.File = $target.Trim('"').Substring(2)
            $state.Skip = & $excluded $state.File
            if (-not $state.Skip) { & $scanPath $state.File 'History' $state.Commit }
            return
        }
        if ($text -match '^Binary files .* and (?:"?b/(.+?)"?) differ$') {
            $file = $Matches[1]
            if (-not (& $excluded $file)) {
                # Git calls UTF-16 text binary (exports often are): read the whole file at that commit.
                & $scanPath $file 'History' $state.Commit
                Find-NSPClientReferenceInContent -Context $context -Bytes (Get-NSPGitBlob -RepoRoot $root -Commit $state.Commit -Path $file) -Scope 'History' -File $file -Commit $state.Commit
            }
            return
        }
        if ($text -match '^@@ -\d+(?:,\d+)? \+(\d+)') { $state.Line = [int]$Matches[1]; return }
        if ($state.Skip -or -not $state.File) { return }
        if ($text.StartsWith('+')) {
            Find-NSPClientReferenceInLine -Context $context -Text $text.Substring(1) -Scope 'History' -File $state.File -Line $state.Line -Commit $state.Commit
            $state.Line++
        }
    } | & $once
}
