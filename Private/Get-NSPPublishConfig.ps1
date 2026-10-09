function Get-NSPPublishConfig {
    # Reads the Publish section of <repo>\.nsp-repotools.psd1. Exclude: wildcards on the
    # repo-relative path (forward slashes), added to the developer files that never ship.
    # Include: when set, only these top-level files and folders ship.
    param([Parameter(Mandatory)][string]$RepoRoot)

    $config = @{ Exclude = @(); Include = @() }
    $path = Join-Path $RepoRoot '.nsp-repotools.psd1'
    if (-not (Test-Path -LiteralPath $path)) { return $config }
    $data = Import-PowerShellDataFile -LiteralPath $path
    if ($data.Publish) {
        foreach ($key in @($config.Keys)) {
            if ($data.Publish.ContainsKey($key)) { $config[$key] = @($data.Publish[$key]) }
        }
    }
    $config
}
