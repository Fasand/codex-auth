# Changelog

Newest releases go at the top.

## 0.4.3 - 2026-03-26

- Documented the retained-tag release policy in `AGENTS.md` so future releases keep `0.x.0` and the latest `0.x.y` tag for each minor line.
- Added README guidance for installing a specific retained tagged version such as `0.3.0`.
- Added smoke coverage for the new tag-install documentation and tagging-policy workflow notes.

## 0.4.2 - 2026-03-26

- Changed interactive refresh progress to use a single live-updating terminal line instead of leaving one progress-bar line per profile.
- Kept non-interactive refresh output simple and line-based, without progress bars, so logs and captured output stay readable.

## 0.4.1 - 2026-03-26

- Added visible refresh progress output so multi-profile usage refreshes show which profile is currently being processed and how far through the batch they are.
- Changed refresh-all flows to continue past per-profile failures, then summarize every failed profile at the end instead of stopping at the first expired token.
- Kept the automatic post-refresh profile list while returning a non-zero exit status when any profile refresh fails.

## 0.4.0 - 2026-03-26

- Switched profile date/time displays to the current local timezone by default and added `--utc` for `list`, `current`, `refresh-usage`, and `refresh`.
- Redesigned the profile table to focus on plan, 5-hour, and weekly limits, with clearer grouped separators, tighter active markers, and optional terminal colors for headers, profiles, resets, and limit percentages.
- Made bare `refresh-usage` / `refresh` confirm an all-profile refresh, then automatically print the updated profile list.

## 0.3.0 - 2026-03-19

- Added a new `codex-auth update` command that self-updates via the existing installer without cloning the repository.
- Updated the help text, README, installer messaging, and Bash completions to document the new self-update path alongside the existing install-script flow.
- Clarified in `AGENTS.md` that slash-style branch names work and that sandboxed Codex sessions may need elevated Git permissions to create branches.

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
