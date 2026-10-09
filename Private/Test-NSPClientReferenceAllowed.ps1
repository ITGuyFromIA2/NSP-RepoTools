function Test-NSPClientReferenceAllowed {
    # True when the repository's .nsp-repotools.psd1 accepts this text (Allow: exact, ignoring
    # case; AllowPattern: regular expressions).
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [string]$Text
    )

    if ($Context.Allow.ContainsKey($Text.ToLowerInvariant())) { return $true }
    foreach ($pattern in $Context.AllowPattern) { if ($Text -match $pattern) { return $true } }
    $false
}
