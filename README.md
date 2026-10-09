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

## Publishing a module

`Publish-NSPModule` is the release routine for every NSP module repository; it replaces each
repo's own `tools\Publish-ToGallery.ps1`.

```powershell
Publish-NSPModule -Path . -WhatIf    # every check and the package list; publishes nothing
Publish-NSPModule -Path .            # asks before the publish itself
```

Nothing is published unless all of these pass:

| Check | Fails when |
|---|---|
| Manifest | There isn't exactly one module manifest at the root, `Test-ModuleManifest` fails, or `FunctionsToExport` doesn't list exactly the `Public\` files. |
| Changelog | `CHANGELOG.md` has no heading for this version, or still marks it unreleased. |
| Git | Anything is uncommitted or untracked, or the tag `v<version>` already exists. |
| Version | The Gallery already has this version or a newer one. |
| Client references | `Find-NSPClientReference -IncludeUntracked -History` finds anything, or your token list is empty. |
| `tools\Test-Repo.ps1` | It exits non-zero (it runs in its own process). |
| Package | The staged copy fails `Test-ModuleManifest` or doesn't import under Windows PowerShell 5.1. |

The package is built from **tracked files only**, so ignored client data (local profiles,
inventories, exports) can't ship. It leaves out `Tests\`, `tools\`, dot files, `CLAUDE.md`,
`AGENTS.md`, `PLAN.md`, and `PSScriptAnalyzerSettings.psd1`, and is staged in a folder named after
the module (`NSP.Console`, not the repository's `NSP-Console`). More exclusions, or a fixed list
of top-level items, go in `.nsp-repotools.psd1`:

```powershell
@{ Publish = @{ Exclude = @('Legacy/*', 'docs/*'); Include = @() } }
```

The publish uses `Microsoft.PowerShell.PSResourceGet` (the legacy PowerShellGet reports success on
failed publishes) with the API key from `Get-NSPSecret -Name MS.PSGallery.ApiKey` (NSP.Bootstrap).
Afterwards it checks that the version is really live, then tags the commit `v<version>` locally
(`-NoTag` skips that). Push the tag yourself.

## Tests

```powershell
.\tools\Test-Repo.ps1
```
