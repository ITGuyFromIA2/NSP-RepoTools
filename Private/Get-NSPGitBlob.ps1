function Get-NSPGitBlob {
    # Returns a file's bytes at a commit (git show <commit>:<path>). Read through the process's
    # stream: PowerShell's native-command pipe would decode, and corrupt, binary content.
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )

    $info = [System.Diagnostics.ProcessStartInfo]::new('git')
    $info.Arguments = '-C "{0}" show "{1}:{2}"' -f $RepoRoot, $Commit, $Path
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($info)
    try {
        $buffer = [IO.MemoryStream]::new()
        $errors = $process.StandardError.ReadToEndAsync()
        $process.StandardOutput.BaseStream.CopyTo($buffer)
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "git show $Commit`:$Path failed: $($errors.Result)" }
        , $buffer.ToArray()
    } finally {
        $process.Dispose()
    }
}
