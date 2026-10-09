function Get-NSPPublishFile {
    # The repo-relative paths (forward slashes) that go into the package: tracked files only, so
    # nothing ignored (client exports, local profiles) can ship, minus the developer files.
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][hashtable]$Config
    )

    $developer = @('Tests/*', 'tools/*', '.*', '*/.*', 'CLAUDE.md', 'AGENTS.md', 'PLAN.md', 'PSScriptAnalyzerSettings.psd1')
    $exclude = $developer + @($Config.Exclude)
    foreach ($relative in @(Invoke-NSPGit -RepoRoot $RepoRoot -Arguments 'ls-files')) {
        if (-not $relative) { continue }
        $topLevel = ($relative -split '/')[0]
        if (@($Config.Include).Count -and @($Config.Include) -notcontains $topLevel) { continue }
        $skip = $false
        foreach ($pattern in $exclude) { if ($relative -like $pattern) { $skip = $true; break } }
        if (-not $skip) { $relative }
    }
}
