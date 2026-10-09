# CLAUDE.md

## What this is

`NSP.RepoTools`: maintainer tools for NSP repositories: the client-reference sweep
(`Find-NSPClientReference`), the per-user client token list, and the release routine
(`Publish-NSPModule`), which replaces each repo's own `tools\Publish-ToGallery.ps1`.

## Hard rules

- No client identifier is ever written into this repository. Client tokens live only in the
  per-user list (`Get-NSPClientTokenPath`). Test data is invented; values the sweep must ignore use
  reserved names (`.example`, `.test`, documentation addresses), and values it must catch are
  invented and listed in `.nsp-repotools.psd1`.
- Gates print locations and rules, never matched text or token sources.
- The sweep only reads. It never edits files or rewrites history.
- Other repositories' Test-Repo gates depend on the sweep's parameters, output properties, and
  rule names. `Tests\SweepContract.Tests.ps1` pins them; change them only on purpose.
- `Publish-NSPModule` publishes nothing unless every check passes, packages tracked files only,
  and confirms before the publish (`ConfirmImpact = 'High'`). Tests mock the Gallery calls
  (`Get-NSPPublishedVersion`, `Invoke-NSPPublishResource`); they never publish or read a secret.
- Windows PowerShell 5.1 is the floor: no `??`, `?.`, ternary, or `-Parallel`.
- Never abbreviate Conditional Access as "CA" (NSP-CAManager owns that noun space).
- One function per file. `FunctionsToExport` matches `Public\`. Exported functions need `.SYNOPSIS` and `.EXAMPLE`.

## Testing

Pester 5+. Run `.\tools\Test-Repo.ps1`. Tests build throwaway Git repositories under `TestDrive`.
