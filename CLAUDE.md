# CLAUDE.md

## What this is

`NSP.RepoTools`: maintainer tools for NSP repositories. First: the client-reference sweep
(`Find-NSPClientReference`) and the per-user client token list. Planned next: the publishing
routine.

## Hard rules

- No client identifier is ever written into this repository. Client tokens live only in the
  per-user list (`Get-NSPClientTokenPath`). Test data is invented; values the sweep must ignore use
  reserved names (`.example`, `.test`, documentation addresses), and values it must catch are
  invented and listed in `.nsp-repotools.psd1`.
- Gates print locations and rules, never matched text or token sources.
- The sweep only reads. It never edits files or rewrites history.
- Windows PowerShell 5.1 is the floor: no `??`, `?.`, ternary, or `-Parallel`.
- Never abbreviate Conditional Access as "CA" (NSP-CAManager owns that noun space).
- One function per file. `FunctionsToExport` matches `Public\`. Exported functions need `.SYNOPSIS` and `.EXAMPLE`.

## Testing

Pester 5+. Run `.\tools\Test-Repo.ps1`. Tests build throwaway Git repositories under `TestDrive`.
