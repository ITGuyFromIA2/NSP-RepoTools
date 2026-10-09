# One function per file. The manifest's FunctionsToExport is the exported surface.
foreach ($folder in 'Private', 'Public') {
    $path = Join-Path $PSScriptRoot $folder
    if (-not (Test-Path -LiteralPath $path)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $path -Filter '*.ps1' -File | Sort-Object Name) {
        try { . $file.FullName }
        catch { throw "NSP.RepoTools: failed to load $($file.Name): $_" }
    }
}
