function Get-NSPClientReferenceRule {
    # The pattern rules that need no token list. Each has a Name, a Regex, and an optional Keep
    # scriptblock that gets the matched text and returns $false to drop a known-safe match.
    [CmdletBinding()]
    param()

    # Reserved for documentation and examples (RFC 2606, RFC 6761), and Microsoft's sample tenants.
    $syntheticDomain = '(?i)(^|\.)(example|test|invalid|localhost|local)$|(^|\.)example\.(com|net|org)$|(^|\.)(contoso|fabrikam|northwindtraders|wingtiptoys|adatum|litware|tailspintoys|woodgrovebank)\.(com|onmicrosoft\.com)$'
    $syntheticMailbox = '(?i)^noreply@anthropic\.com$|@users\.noreply\.github\.com$|^(user|someone|admin|name|first\.last|firstname\.lastname)@'

    @(
        [pscustomobject]@{
            Name = 'Email'
            Regex = [regex]'(?i)(?<![A-Za-z0-9._%+-])[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}(?![A-Za-z0-9-])'
            Keep = {
                param($Text)
                $domain = $Text.Split('@')[1]
                if ($domain -match '^odata\.') { return $false }
                -not ($domain -match $syntheticDomain -or $Text -match $syntheticMailbox)
            }.GetNewClosure()
        }
        [pscustomobject]@{
            Name = 'TenantName'
            Regex = [regex]'(?i)(?<![@A-Za-z0-9.-])[A-Za-z0-9-]+\.onmicrosoft\.com(?![A-Za-z0-9-])'
            Keep = {
                param($Text)
                -not ($Text -match $syntheticDomain -or $Text -match '(?i)^(your|tenant|yourtenant|mytenant|client|clienttenant|<[^>]*>)')
            }.GetNewClosure()
        }
        [pscustomobject]@{
            Name = 'UncPath'
            Regex = [regex]'\\\\[A-Za-z0-9._-]+\\[A-Za-z0-9$._-]+'
            Keep = {
                param($Text)
                $server = $Text.Substring(2).Split('\')[0]
                $server -notmatch '(?i)^(server|servername|fileserver|fs|host|hostname|computer|computername|localhost|wsl\$|\?|\.|contoso.*|example.*)$'
            }
        }
        [pscustomobject]@{
            Name = 'UserProfilePath'
            Regex = [regex]'(?i)\b[A-Z]:\\Users\\[^\\\s''"<>%$*{}]+'
            Keep = {
                param($Text)
                $user = $Text.Split('\')[2]
                $user -notmatch '(?i)^(public|default|default user|all users|username|user|you|me|someone|administrator)$'
            }
        }
        [pscustomobject]@{
            Name = 'PublicIPv4'
            Regex = [regex]'(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])'
            Keep = {
                param($Text)
                $o = @($Text.Split('.') | ForEach-Object { [int]$_ })
                if (@($o | Where-Object { $_ -gt 255 }).Count) { return $false }
                $a = $o[0]; $b = $o[1]; $c = $o[2]
                if ($a -in 0, 10, 127 -or $a -ge 224) { return $false }               # this-host, private, loopback, multicast, reserved
                if ($a -eq 100 -and $b -ge 64 -and $b -le 127) { return $false }      # carrier-grade NAT
                if ($a -eq 169 -and $b -eq 254) { return $false }                     # link-local
                if ($a -eq 172 -and $b -ge 16 -and $b -le 31) { return $false }       # private
                if ($a -eq 192 -and $b -eq 168) { return $false }                     # private
                if ($a -eq 192 -and $b -eq 0 -and $c -in 0, 2) { return $false }      # IETF, documentation
                if ($a -eq 198 -and $b -in 18, 19) { return $false }                  # benchmarking
                if ($a -eq 198 -and $b -eq 51 -and $c -eq 100) { return $false }      # documentation
                if ($a -eq 203 -and $b -eq 0 -and $c -eq 113) { return $false }       # documentation
                # Well-known public resolvers are not anyone's address.
                $Text -notin '1.1.1.1', '1.0.0.1', '8.8.8.8', '8.8.4.4', '9.9.9.9', '149.112.112.112', '208.67.222.222', '208.67.220.220', '4.2.2.2'
            }
        }
        [pscustomobject]@{
            Name = 'PrivateKey'
            Regex = [regex]'-----BEGIN (?:[A-Z]+ )*PRIVATE KEY-----'
            Keep = $null
        }
    )
}
