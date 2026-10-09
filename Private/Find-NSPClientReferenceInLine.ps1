function Find-NSPClientReferenceInLine {
    # Applies the token pattern and the rules to one line of text. $Context carries TokenRegex
    # (or $null), TokenSource (lower-cased token -> source), Rules, and the Allow checks.
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [AllowEmptyString()][string]$Text,
        [string]$Scope,
        [string]$File,
        [int]$Line,
        [string]$Commit
    )

    if (-not $Text) { return }
    $found = [System.Collections.Generic.List[object]]::new()
    if ($Context.TokenRegex) {
        foreach ($m in $Context.TokenRegex.Matches($Text)) {
            $found.Add(@('ClientToken', $m.Value, $Context.TokenSource[$m.Value.ToLowerInvariant()]))
        }
    }
    foreach ($rule in $Context.Rules) {
        foreach ($m in $rule.Regex.Matches($Text)) {
            if ($rule.Keep -and -not (& $rule.Keep $m.Value)) { continue }
            $found.Add(@($rule.Name, $m.Value, 'pattern'))
        }
    }
    foreach ($f in $found) {
        if (Test-NSPClientReferenceAllowed -Context $Context -Text $f[1]) { continue }
        [pscustomobject]@{ Scope = $Scope; File = $File; Line = $Line; Commit = $Commit; Rule = $f[0]; Match = $f[1]; Source = $f[2] }
    }
}
