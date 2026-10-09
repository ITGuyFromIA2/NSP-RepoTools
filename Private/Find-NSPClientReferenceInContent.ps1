function Find-NSPClientReferenceInContent {
    # Scans a file's content line by line. UTF-8 and UTF-16 with a byte-order mark are read as
    # text; anything else holding a NUL byte is reported as Unscanned.
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [AllowEmptyCollection()][byte[]]$Bytes,
        [string]$Scope,
        [string]$File,
        [string]$Commit
    )

    if (-not $Bytes -or -not $Bytes.Length) { return }
    $unicode = $Bytes.Length -ge 2 -and (($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) -or ($Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF))
    if (-not $unicode -and [Array]::IndexOf($Bytes, [byte]0) -ge 0) {
        if (-not (Test-NSPClientReferenceAllowed -Context $Context -Text $File)) {
            [pscustomobject]@{ Scope = $Scope; File = $File; Line = 0; Commit = $Commit; Rule = 'Unscanned'; Match = 'binary file'; Source = 'path' }
        }
        return
    }
    $reader = [IO.StreamReader]::new([IO.MemoryStream]::new($Bytes), [System.Text.UTF8Encoding]::new($false), $true)
    try {
        $number = 0
        while ($null -ne ($text = $reader.ReadLine())) {
            $number++
            Find-NSPClientReferenceInLine -Context $Context -Text $text -Scope $Scope -File $File -Line $number -Commit $Commit
        }
    } finally { $reader.Dispose() }
}
