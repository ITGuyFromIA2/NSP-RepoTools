function Get-NSPClientTokenPath {
    <#
    .SYNOPSIS
        Returns the path of this user's client token list.
    .DESCRIPTION
        The list holds the client names, domains, tenant IDs, and other identifiers that
        Find-NSPClientReference searches for. It lives outside every repository, under
        %LOCALAPPDATA%\NSP\RepoTools\ClientTokens.csv, so the identifiers themselves are never
        committed. NSP_CLIENT_TOKENS overrides the path (tests, a shared encrypted drive).
    .EXAMPLE
        Get-NSPClientTokenPath
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($env:NSP_CLIENT_TOKENS) { return $env:NSP_CLIENT_TOKENS }
    $base = $env:LOCALAPPDATA
    if (-not $base) { $base = [Environment]::GetFolderPath('LocalApplicationData') }
    Join-Path $base 'NSP\RepoTools\ClientTokens.csv'
}
