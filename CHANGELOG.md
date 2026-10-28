# Changelog

## Unreleased

- Bootstrap publishing fallback supports both toolkit-sibling and legacy parent checkouts.
- Test-Repo selects PowerShell source files explicitly in Windows PowerShell 5.1 and 7, excluding documentation and Git metadata. A regression fixture covers nested literal paths.

## 0.1.1

- Fewer false findings in real module code: PublicIPv4 skips `1.x.x.x` (version strings such as `1.4.8.1`, and the `1.2.3.4` placeholder) and `2.5.x.y` (X.509 object identifiers such as `2.5.29.19`); UncPath skips `\\name\.ext` (an escaped dot in a regular expression) and Microsoft's `fabrikam` sample server.

## 0.1.0

- `Find-NSPClientReference`: sweeps tracked and untracked files, file paths, Git history, and
  commit messages for client tokens and for e-mail addresses, tenant names, UNC and user-profile
  paths, public IPv4 addresses, private keys, key files, and unreadable binaries. Per-repository
  exclusions and allow lists in `.nsp-repotools.psd1`.
- Per-user client token list outside every repository: `Get-NSPClientTokenPath`,
  `Get-NSPClientToken`, `Add-NSPClientToken` (direct, or harvested from JSON exports),
  `Remove-NSPClientToken`.
- `Publish-NSPModule`: the release routine for NSP module repositories. Checks the manifest,
  exports, changelog, clean tree, Gallery version, client references (history included), and the
  repository's own `tools\Test-Repo.ps1`; packages tracked runtime files only; publishes with
  PSResourceGet, confirms the version is live, and tags `v<version>` locally.
