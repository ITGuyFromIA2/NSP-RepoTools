function Invoke-NSPGit {
    # Streams git's output lines, decoded as UTF-8, and throws on a non-zero exit.
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $previous = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        & git -C $RepoRoot -c core.quotepath=off @Arguments
        if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE." }
    } finally {
        [Console]::OutputEncoding = $previous
    }
}
