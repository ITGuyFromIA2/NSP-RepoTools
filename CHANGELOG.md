# Changelog

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
