function Remove-NSPClientToken {
    <#
    .SYNOPSIS
        Removes tokens from this user's client token list.
    .DESCRIPTION
        For tokens that identify no one and only cause noise ("admin", "breakglass"). Matching
        ignores case; -Pattern removes every token matching a regular expression.
    .EXAMPLE
        Remove-NSPClientToken -Token 'admin', 'breakglass'
    .EXAMPLE
        Remove-NSPClientToken -Pattern '^Group-' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$Token = @(),
        [string[]]$Pattern = @(),
        [string]$Path = (Get-NSPClientTokenPath)
    )

    $drop = @{}
    foreach ($t in $Token) { $drop[$t.Trim().ToLowerInvariant()] = $true }
    $existing = @(Get-NSPClientToken -Path $Path)
    $keep = [System.Collections.Generic.List[object]]::new()
    $removed = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $existing) {
        $gone = $drop.ContainsKey($row.Token.ToLowerInvariant())
        foreach ($p in $Pattern) { if ($row.Token -match $p) { $gone = $true } }
        if ($gone) { $removed.Add($row) } else { $keep.Add($row) }
    }
    if ($removed.Count -and $PSCmdlet.ShouldProcess($Path, "Remove $($removed.Count) client token(s)")) {
        @($keep) | Sort-Object Source, Token | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
    }
    [pscustomobject]@{ Path = $Path; Removed = $removed.Count; Total = $keep.Count }
}
