# Changelog

Newest releases go at the top.

## 0.11.1 - 2026-08-11

- `codex-auth add <name> --device-auth` runs `codex login --device-auth` (device-code flow) for headless/remote machines where the browser + localhost callback flow fails — curling the printed localhost URL cannot complete the OAuth exchange.
- When browser-based login fails, `add` now points at the `--device-auth` alternative.

## 0.11.0 - 2026-08-11

- Added `codex-auth refresh-tokens [<name>|--all] [--force]`: rotates saved OAuth tokens directly via the same refresh grant the Codex CLI uses, without running a model request. By default it only rotates profiles whose access token has less than 5 days of life left (`CODEX_AUTH_REFRESH_TOKENS_MIN_VALID_SECONDS`), always operates on the live `auth.json` when it belongs to the target account (so a superseded snapshot refresh token is never replayed — replaying one gets the whole grant revoked server-side), and heals the snapshot from the live chain.
- Scheduled cron jobs now run `refresh-tokens` + `refresh-usage` instead of `touch`: token keep-alive no longer burns plan usage (daily `codex exec` touches were eating free-plan limits) and no longer swaps the live `auth.json` around under running Codex sessions.
- `codex-auth add` now stashes the live `auth.json` away before running `codex login` (and restores it if login fails). `codex login`/`codex logout` revoke whatever tokens they find, which was the main way a previously working profile's refresh token got invalidated during account switches. Never run bare `codex logout` to switch accounts.
- Rate-limit windows are no longer assumed to be 5h + weekly. The ChatGPT backend now reports a single plan-dependent window (e.g. 7 days on Plus, 30 days on free) via `limit_window_seconds`; `list`, `current`, the switch picker, and session snapshots now label each window from its actual duration (`weekly 97%`, `30d 0%`) under generic LIMIT columns.
- Re-login guidance now points at `codex-auth add <profile>` instead of `codex logout && codex login` chains (`codex login` has also revoked existing auth before starting since Codex 0.140.0, so even bare re-logins kill the live account's profile).
- Added a `RELEASE_NOTES` mechanism: updates and update prompts now show a short "What's new" message for every version newer than the installed one, so behavior changes reach users who never read the changelog.
- Profile lines now show a `credits=` segment when the account has a usage-based credit balance (the usage payload's new `credits` block).
- `touch` snapshot syncing now verifies the live `auth.json` belongs to the touched profile's account before overwriting the snapshot, so a concurrent Codex session writing its own tokens mid-touch can no longer cross-contaminate profiles (and a refused sync now fails the touch instead of reporting success).
- Hardening from cross-model review: `add` restores the stashed auth on interrupt and keeps the stash until the new profile is saved; the refresh-tokens lock is cleaned up on interrupt; token files are written 0600 from creation; a refresh response without replacement tokens is rejected without touching the auth file; a concurrent rewrite of the auth file during rotation parks the new tokens in a `.rotated` sidecar instead of clobbering; rotation failures recorded in `usage.json` now survive later successful usage refreshes.

## 0.10.2 - 2026-07-18

- Made `codex-auth switch` warn (instead of silently proceeding) when the restored snapshot's access token is already expired or the snapshot has no refresh token — the moment Codex is forced onto the refresh token, which is when an upstream-rotated (dead) refresh token surfaces as an immediate re-login prompt. The warning points at `codex-auth touch`, re-login, and `codex-auth cron setup` to verify/repair or keep snapshots fresh (DEV-259).
- Documented in the README that OpenAI issues one live refresh token per account and rotates it on every refresh/new login, so point-in-time snapshots go stale; `codex-auth touch`/`cron` are the way to keep switching reliable.

## 0.10.1 - 2026-07-12

- Made `codex-auth update` report the version transition (`0.10.0 → 0.10.1`) with the same terminal colors as the rest of the CLI, and hide the installer output unless it fails.
- Made `codex-auth update` say "already up to date" (and skip the reinstall) when the published version is not newer than the installed one.
- Colored the daily update-check prompt versions to match.

## 0.10.0 - 2026-07-12

- Added a daily automatic update check for installed copies: the first interactive command of the day compares against the published `VERSION` and offers `Update now? [Y/n]`; accepting updates in place and skips the original command. Non-interactive runs, cron jobs, local checkouts, and any network failure silently skip the check (`CODEX_AUTH_NO_UPDATE_CHECK=1` opts out).
- Made bare `refresh-usage` / `refresh` refresh all saved profiles directly, without the confirmation prompt (DEV-137).
- Marked usage percentages that did not come straight from the primary usage endpoint with a `~` prefix, so numbers backfilled from local session snapshots or fetched from the fallback endpoint can no longer masquerade as live data (fixes the flip-flopping `refresh` readings).
- Ignored local session snapshots older than one hour when backfilling usage, since rollout files carry no account identity and stale windows can describe a different login.
- Added the account-identity guard to the stale-snapshot live-token fallback in `refresh-usage`, preventing a live `auth.json` from another account from being queried as the profile or synced over its snapshot.
- Consolidated the switch pre-save and refresh fallback identity checks into one shared helper.

## 0.9.0 - 2026-06-04

- Added `cron` commands to list, set up, add, delete, and run managed scheduled `touch` jobs.
- Added an interactive `cron setup` wizard for daily or custom touch schedules, using `whiptail` when available and colored numbered prompts as a fallback.
- Added timestamped scheduled-touch logging under `~/.codex/accounts/cron/touch.log` and managed crontab markers for safe deletion.

## 0.8.0 - 2026-06-04

- Added `token-status` to inspect saved profile ID-token and access-token expirations without changing the main profile list; it defaults to all profiles and uses the same active marker/color style as `list`.
- Added `touch <profile>|--all` to switch through profiles, run a minimal Codex request, persist the live auth snapshot, report whether tokens actually rotated, and restore the original profile.
- Started tracking both ID-token and access-token expiration metadata in saved profile `meta.json` files.
- Clarified that `refresh` / `refresh-usage` refresh live usage data, not OAuth tokens.

## 0.7.0 - 2026-04-21

- Persist the latest per-profile refresh failure in `usage.json` so `list` and `current` keep showing unresolved refresh problems until the next successful refresh clears them.
- Group profiles with refresh problems at the end of `list`, separated by a rule, with the affected profile name and compact issue reason highlighted in red.

## 0.6.0 - 2026-04-21

- Made local session statistics opt-in for `list` and post-refresh output via `--with-stats`, so ordinary profile listing and usage refreshes avoid parsing rollout history and pricing by default.
- Added a parsed session-stats cache keyed by rollout file path, size, and mtime, plus `stats --recompute` to force a full rebuild when desired.
- Increased the default OpenAI pricing cache TTL from one day to one week and documented the new stats/pricing cache behavior.

## 0.5.1 - 2026-04-12

- Fixed session statistics pricing so older Codex models like `gpt-5.3-codex`, `gpt-5.2-codex`, `gpt-5.1-codex-mini`, and `gpt-5.1-codex-max` are read from the official single OpenAI pricing page instead of falling back to `gpt-5.4`.
- Tightened pricing-page parsing so only standard-tier rows are used even when the page mixes multiple standard and priority table layouts.
- Improved pricing-basis formatting so small cached-input rates display with enough precision to audit the calculation.

## 0.5.0 - 2026-04-12

- Added a new global `stats` command, with `statistics` as an alias, to summarize historical Codex rollout token usage across today, 7d, 14d, 30d, and all-time windows.
- Added compact session-usage footer lines to `list` so today and 7d session counts, token totals, and estimated API-equivalent costs are visible without opening the full stats view.
- Added daily and model breakdowns plus cached official-pricing-based API-equivalent cost estimation, including fallback pricing for unknown-model session events.

## 0.4.4 - 2026-03-31

- Added fallback to the live Codex session token when `refresh-usage` fails with a token_expired 401 on the currently active profile. If the live token succeeds, the stale profile snapshot is auto-synced; if both tokens are expired, a distinct error message is shown.
- Added silent token sync on `switch`: before switching away from the current profile, the live `auth.json` is copied back to the outgoing profile's snapshot and its meta.json is refreshed, preventing snapshot staleness.
- Added identity guard for switch pre-save: before overwriting the outgoing profile snapshot, the live auth.json's account_id/email is verified against the profile's meta.json. If the accounts don't match (e.g. after a manual `codex logout && codex login` to a different account), the pre-save is silently skipped to prevent cross-contamination.

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
