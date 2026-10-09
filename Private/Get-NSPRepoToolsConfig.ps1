function Get-NSPRepoToolsConfig {
    # Reads <repo>\.nsp-repotools.psd1. ClientSweep keys: ExcludePath (wildcards on the
    # repo-relative path, forward slashes), Allow (exact strings), AllowPattern (regexes).
    # The file is tracked: it may name what is accepted, never a client.
    param([Parameter(Mandatory)][string]$RepoRoot)

    $config = @{ ExcludePath = @(); Allow = @(); AllowPattern = @() }
    $path = Join-Path $RepoRoot '.nsp-repotools.psd1'
    if (-not (Test-Path -LiteralPath $path)) { return $config }
    $data = Import-PowerShellDataFile -LiteralPath $path
    if ($data.ClientSweep) {
        foreach ($key in @($config.Keys)) {
            if ($data.ClientSweep.ContainsKey($key)) { $config[$key] = @($data.ClientSweep[$key]) }
        }
    }
    $config
}
