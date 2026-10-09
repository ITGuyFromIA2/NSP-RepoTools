function Add-NSPClientToken {
    <#
    .SYNOPSIS
        Adds client identifiers to this user's token list.
    .DESCRIPTION
        Tokens are what Find-NSPClientReference searches for: client names and abbreviations,
        domains, tenant names and IDs, object IDs, user and group names. Give them directly with
        -Token, or harvest them from local JSON exports (inventories, profiles) with -FromJson.

        -FromJson walks every object in the files and takes the string values (or lists of strings)
        of the properties named in -Property, plus every e-mail address anywhere. Properties named in
        -ExcludeProperty are skipped with everything under them (use it for Microsoft catalogs
        such as role templates, which are not client data).

        For a domain or e-mail address, its organization label is added too: acme-widgets.com adds
        acme-widgets, and contoso.onmicrosoft.com adds contoso. Tokens shorter than -MinimumLength, and
        tokens matching an -ExcludePattern, are skipped. The list is de-duplicated, ignoring case.
    .EXAMPLE
        Add-NSPClientToken -Token 'Acme', 'Acme Widgets' -Source 'client name'
    .EXAMPLE
        Add-NSPClientToken -FromJson (Get-ChildItem .\exports -Filter *.json -Recurse).FullName -ExcludeProperty RoleTemplates
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Used by the nested helpers, which the analyzer does not follow.')]
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Token')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Token', ValueFromPipeline, Position = 0)]
        [AllowEmptyString()][string[]]$Token,

        [Parameter(Mandatory, ParameterSetName = 'Json')]
        [string[]]$FromJson,

        [Parameter(ParameterSetName = 'Json')]
        [string[]]$Property = @('id', 'tenantId', 'displayName', 'userPrincipalName', 'mail', 'name', 'domain', 'tenantDomain', 'cidrAddress', 'onPremisesSamAccountName', 'companyName'),

        [Parameter(ParameterSetName = 'Json')]
        [string[]]$ExcludeProperty = @(),

        [string]$Source,
        [string[]]$ExcludePattern = @(),
        [ValidateRange(1, 100)][int]$MinimumLength = 4,
        [string]$Path = (Get-NSPClientTokenPath)
    )

    begin {
        $collected = [System.Collections.Generic.List[object]]::new()
        $mailProviders = @('gmail', 'outlook', 'hotmail', 'yahoo', 'icloud', 'live', 'microsoft', 'onmicrosoft', 'example', 'contoso', 'fabrikam')
        $emailPattern = '^[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})$'
        $domainPattern = '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$'

        function Add-One([string]$Value, [string]$From) {
            if ($null -eq $Value) { return }
            $v = $Value.Trim()
            if ($v.Length -lt $MinimumLength) { return }
            foreach ($pattern in $ExcludePattern) { if ($v -match $pattern) { return } }
            $collected.Add([pscustomobject]@{ Token = $v; Source = $From })
            # The organization label of a domain: the part before .onmicrosoft.com, or before the suffix.
            $domain = if ($v -match $emailPattern) { $Matches[1] } elseif ($v -match $domainPattern) { $v } else { $null }
            if ($domain) {
                $labels = $domain.ToLowerInvariant().Split('.')
                $label = if ($domain -match '\.onmicrosoft\.com$') { $labels[0] } else { $labels[$labels.Count - 2] }
                if ($label.Length -ge $MinimumLength -and $label -notin $mailProviders) {
                    $skip = $false
                    foreach ($pattern in $ExcludePattern) { if ($label -match $pattern) { $skip = $true } }
                    if (-not $skip) { $collected.Add([pscustomobject]@{ Token = $label; Source = $From }) }
                }
            }
        }

        function Get-JsonValue($Node, [string]$From) {
            if ($null -eq $Node) { return }
            if ($Node -is [string]) {
                if ($Node -match $emailPattern) { Add-One $Node $From }
                return
            }
            if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [System.Collections.IDictionary]) {
                foreach ($item in $Node) { Get-JsonValue $item $From }
                return
            }
            if ($Node -is [System.Management.Automation.PSCustomObject]) {
                foreach ($p in $Node.PSObject.Properties) {
                    if ($p.Name -in $ExcludeProperty) { continue }
                    if ($p.Name -in $Property) {
                        # A named property may hold one string or a list of them (a profile's Ids).
                        foreach ($v in @($p.Value)) { if ($v -is [string]) { Add-One $v $From } }
                    }
                    Get-JsonValue $p.Value $From
                }
            }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Token') {
            $from = if ($Source) { $Source } else { 'manual' }
            foreach ($t in $Token) { Add-One $t $from }
        }
    }

    end {
        if ($PSCmdlet.ParameterSetName -eq 'Json') {
            foreach ($file in $FromJson) {
                $from = if ($Source) { $Source } else { [IO.Path]::GetFileName($file) }
                $json = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
                Get-JsonValue $json $from
            }
        }

        $existing = @(Get-NSPClientToken -Path $Path)
        $known = @{}
        foreach ($row in $existing) { $known[$row.Token.ToLowerInvariant()] = $true }
        $new = [System.Collections.Generic.List[object]]::new()
        foreach ($row in $collected) {
            $key = $row.Token.ToLowerInvariant()
            if ($known.ContainsKey($key)) { continue }
            $known[$key] = $true
            $new.Add($row)
        }

        if ($new.Count -and $PSCmdlet.ShouldProcess($Path, "Add $($new.Count) client token(s)")) {
            $folder = Split-Path -Parent $Path
            if ($folder -and -not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
            @($existing) + @($new) | Sort-Object Source, Token | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
        }
        [pscustomobject]@{ Path = $Path; Added = $new.Count; Total = $existing.Count + $new.Count }
    }
}
