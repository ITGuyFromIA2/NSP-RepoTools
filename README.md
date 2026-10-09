# NSP.RepoTools

Maintainer tools for NSP repositories. Windows PowerShell **5.1** compatible (and 7+). Needs `git`
on the PATH.

## Client-reference sweep

Before a repository is shared, published, or made public, check it for client names, tenants,
addresses, and paths:

```powershell
Import-Module NSP.RepoTools
Find-NSPClientReference -Path . -IncludeUntracked | Format-Table Scope, Rule, File, Line, Match
Find-NSPClientReference -Path . -History | Group-Object Rule, Match | Sort-Object Count -Descending
```

It reports:

| Rule | What |
|---|---|
| `ClientToken` | Anything in your client token list (below). |
| `Email` | E-mail addresses, except the reserved example domains (`.example`, `.test`, `.invalid`, `example.com`, `contoso.com`, ...), placeholder mailboxes, and `@odata` annotations. |
| `TenantName` | `<name>.onmicrosoft.com`, except Microsoft's sample tenants. |
| `UncPath` | `\\server\share`, except placeholder server names. |
| `UserProfilePath` | `C:\Users\<name>`: a workstation path that names someone. |
| `PublicIPv4` | Public IPv4 addresses. Private, documentation, and well-known resolver addresses are skipped. |
| `PrivateKey` | A PEM private key block. |
| `KeyOrCertificateFile` | A `.pfx`, `.p12`, `.pem`, `.key`, `.cer`, or `.crt` file. |
| `Unscanned` | A binary file (a screenshot, an export) that could not be read as text: look at it. |

Scopes: `WorkingTree` (tracked files), `Untracked` (with `-IncludeUntracked`: what `git add -A`
would pick up), `History` and `CommitMessage` (with `-History`: every line ever added on any ref,
and every commit message). A history finding is reported once, at the newest commit that adds it.
UTF-16 files (Git shows them as binary; exports often are) are read whole at that commit.
Deleting a file does not remove it from history; that takes a rewrite (`git filter-repo`) and a
force-push, which is a separate decision.

File paths are checked too (`Line` 0).

## The client token list

Client identifiers can't live in the repositories being checked, so the list is per user, at
`%LOCALAPPDATA%\NSP\RepoTools\ClientTokens.csv` (`Get-NSPClientTokenPath`; `NSP_CLIENT_TOKENS`
overrides it). Columns: `Token`, `Source`.

```powershell
Add-NSPClientToken -Token 'Client Name', 'CN', 'clientdomain.com' -Source 'client: Client Name'
Add-NSPClientToken -FromJson (Get-ChildItem .\exports -Recurse -Filter *.json).FullName -ExcludeProperty RoleTemplates
Get-NSPClientToken | Group-Object Source
Remove-NSPClientToken -Token 'admin', 'breakglass'    # generic words only add noise
```

- Tokens match as whole words, ignoring case: `ATES` does not match `updates`.
- A domain or e-mail address also adds its organization label (`acme-widgets.com` adds `acme-widgets`).
- Tokens shorter than four characters are skipped (`-MinimumLength`): too many false hits.
- `-FromJson` takes the values of common identifier properties (`id`, `displayName`,
  `userPrincipalName`, `mail`, `tenantId`, ...) and every e-mail address. Exclude catalogs that
  aren't client data, and use `-ExcludePattern` for your own naming (for example `'^NSP-'`), which
  appears in client exports because you created it there.

## Per-repository settings

A tracked `.nsp-repotools.psd1` at the repository root:

```powershell
@{
    ClientSweep = @{
        ExcludePath  = @('Legacy/*')            # wildcards on the repo-relative path
        Allow        = @('support@example.com') # exact text that is fine here
        AllowPattern = @()                      # regular expressions
    }
}
```

It is tracked, so it may name what is accepted, never a client.

## In a Test-Repo gate

Print locations and rules, never the matched text or its source, so a build log can't leak what
it caught:

```powershell
$hits = @(Find-NSPClientReference -Path $repoRoot -IncludeUntracked -WarningAction SilentlyContinue)
$hits | ForEach-Object { Write-Host "$($_.File):$($_.Line) [$($_.Rule)]" }
```

Without a token list (a build agent), only the pattern rules run.

## Tests

```powershell
.\tools\Test-Repo.ps1
```
