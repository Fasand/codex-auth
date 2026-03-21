# Codex Auth Usage Sync Design

**Date:** 2026-03-08

## Goal
Improve `codex-auth` so its usage display matches Codex CLI more closely for the active account, while still caching account-level usage for saved profiles. Move the tracked script into `~/Developer/reference-architecture/bin` and keep profile data under `~/.codex/accounts`.

## Root Cause Findings
- The current script queries `https://chatgpt.com/backend-api/codex/usage`, which returns account-level rate limits using `used_percent`.
- Codex CLI’s status line uses both session-level token-count events and rate-limit snapshots.
- The `258K window` display comes from the model’s effective context window (`272000 * 95% = 258400`).
- The CLI status line appears to show **remaining** percentages for the 5h/weekly sections, while the backend payload stores **used** percentages.
- The current script therefore refreshes data correctly enough at the backend layer, but displays it with the wrong semantics and without the session-derived context fields.

## Desired Output Model
For the active current account, display a CLI-style summary based on the most recent session token-count event when available:
- `<context-used>% used`
- `<effective-window> window`
- `5h <remaining>%`
- `weekly <remaining>%`

For inactive saved profiles, show stored account metadata and cached backend usage, focused on whether the account is usable:
- `5h <remaining>%`
- `weekly <remaining>%`
- reset timestamps / time remaining
- fetched timestamp

## Data Sources
1. **Backend usage endpoint** (`/backend-api/codex/usage`)
   - best for account-level cache and refresh timing
   - should be stored per profile in `usage.json`
2. **Latest session token_count event** from `~/.codex/sessions/**/rollout-*.jsonl`
   - best for matching Codex CLI for the currently active session/account
   - should be parsed only for the active current auth snapshot
3. **Model metadata** from `~/.codex/models_cache.json` and/or token_count payload’s `model_context_window`
   - used to render the effective context window

## Storage Changes
Keep using `~/.codex/accounts/profiles/<name>/usage.json`, but enrich it with:
- backend account usage data
- optional session snapshot for current active account, including:
  - total token usage
  - model context window
  - primary/secondary used percents
  - derived display fields (`context_used_percent`, `five_hour_remaining_percent`, `weekly_remaining_percent`)
  - captured timestamp

## Relocation
Move the script from `~/.codex/bin/codex-auth` to:
- `~/Developer/reference-architecture/bin/codex-auth`

Update `~/.bashrc` to add that directory to `PATH` without duplication.

## Risks
- Session token-count parsing depends on Codex rollout JSONL event format.
- The most recent session file may not correspond to the currently relevant active session in edge cases.
- Backend and session timestamps can briefly disagree.

## Mitigations
- Treat session-derived data as best-effort and label/store capture timestamps.
- Fall back gracefully to backend-only display if no session snapshot is available.
- Prefer the most recent token-count event from the newest rollout file.
