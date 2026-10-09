function Get-NSPClientToken {
    <#
    .SYNOPSIS
        Reads client token lists.
    .DESCRIPTION
        Returns one object per distinct token (Token, Source). A .csv file has Token and Source
        columns; any other file holds one token per line, with # starting a comment. A missing
        file returns nothing.
    .EXAMPLE
        Get-NSPClientToken | Group-Object Source | Sort-Object Count -Descending
    #>
    [CmdletBinding()]
    param(
        [string[]]$Path = @(Get-NSPClientTokenPath)
    )

    $seen = @{}
    foreach ($file in $Path) {
        if (-not (Test-Path -LiteralPath $file)) { continue }
        $rows = if ([IO.Path]::GetExtension($file) -eq '.csv') {
            Import-Csv -LiteralPath $file
        } else {
            Get-Content -LiteralPath $file | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') } |
                ForEach-Object { [pscustomobject]@{ Token = $_.Trim(); Source = [IO.Path]::GetFileName($file) } }
        }
        foreach ($row in $rows) {
            $value = ([string]$row.Token).Trim()
            if (-not $value -or $seen.ContainsKey($value.ToLowerInvariant())) { continue }
            $seen[$value.ToLowerInvariant()] = $true
            [pscustomobject]@{ Token = $value; Source = [string]$row.Source }
        }
    }
}
