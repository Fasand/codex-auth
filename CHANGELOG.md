# Changelog

Newest releases go at the top.

## 0.2.2 - 2026-03-19

- Added this historical changelog so releases are tracked by version instead of by commit.
- Added `AGENTS.md` with the repo workflow for branches, PRs, version bumps, verification, and changelog updates.
- Updated the docs to point readers at the changelog and the new current version.

## 0.2.1 - 2026-03-19

- Tightened the dependency preflight output so it stays compact and focuses on what is missing or relevant.
- Fixed multiple macOS Bash compatibility issues around empty-array handling in dependency checks.
- Updated smoke CI to avoid duplicate PR runs and moved GitHub Actions checkout to a Node 24-ready version.
- Hardened smoke tests around installer behavior and dependency reporting.

## 0.2.0 - 2026-03-19

- Added app versioning with a `VERSION` file and `codex-auth --version` / `-v`.
- Added dependency preflight checks plus optional best-effort dependency installation in `install.sh`.
- Made the installer default to this repo's `main` branch while keeping `--from` available for forks and PR testing.
- Added a graceful fallback when `column` is missing, plus initial cross-platform smoke tests and CI.

## 0.1.1 - 2026-03-19

- Updated install and documentation references to use the public `Fasand/codex-auth` repository.
- Polished the public install/update flow around the real GitHub raw URLs.

## 0.1.0 - 2026-03-19

- Initial public-ready release of `codex-auth` as a standalone repository.
- Split the utility out of `reference-architecture` and packaged it for sharing.
- Added the executable, Bash completions, installer, README, and MIT license.
