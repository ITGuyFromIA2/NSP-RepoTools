# Changelog

## 0.1.0 (unreleased)

- `Find-NSPClientReference`: sweeps tracked and untracked files, file paths, Git history, and
  commit messages for client tokens and for e-mail addresses, tenant names, UNC and user-profile
  paths, public IPv4 addresses, private keys, key files, and unreadable binaries. Per-repository
  exclusions and allow lists in `.nsp-repotools.psd1`.
- Per-user client token list outside every repository: `Get-NSPClientTokenPath`,
  `Get-NSPClientToken`, `Add-NSPClientToken` (direct, or harvested from JSON exports),
  `Remove-NSPClientToken`.
