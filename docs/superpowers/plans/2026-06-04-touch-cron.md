# Touch Cron Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a managed `codex-auth cron` command group for scheduled `touch` runs.

**Architecture:** Extend the existing Bash CLI with crontab read/write helpers, managed marker parsing, a small interactive wizard, and a cron-facing runner that delegates to `touch_command`. Keep all persistent scheduling state in the user's crontab and logs under `~/.codex/accounts/cron/`.

**Tech Stack:** Bash, Python snippets already used by `bin/codex-auth`, user crontab, existing smoke tests.

---

### Task 1: Tests for command surface and managed crontab blocks

**Files:**
- Modify: `tests/smoke.sh`

- [ ] Add tests that `help` and bash completion include `cron`.
- [ ] Add a fake `crontab` helper for tests.
- [ ] Add tests for `cron add --time 08:30 --yes`, `cron list`, and `cron delete JOB --yes`.
- [ ] Run `bash tests/smoke.sh` and verify it fails before production code exists.

### Task 2: Core crontab helpers and command dispatch

**Files:**
- Modify: `bin/codex-auth`

- [ ] Add constants for cron log path and optional `CODEX_AUTH_CODEX_BIN`.
- [ ] Add helpers for shell quoting, executable path resolution, crontab list/install, marker parsing, block add/delete, and lock handling.
- [ ] Add `cron` dispatch in `main` and help text.
- [ ] Run smoke tests and iterate.

### Task 3: Interactive wizard and cron runner

**Files:**
- Modify: `bin/codex-auth`
- Modify: `tests/smoke.sh`

- [ ] Implement `cron setup` prompts: target, schedule, time/custom expression, preview, confirmation.
- [ ] Implement `cron run JOB_ID (--all|PROFILE)` with timestamped start/end lines and delegation to `touch_command`.
- [ ] Add smoke tests for the wizard path and `cron run` timestamp/log output.

### Task 4: Release/documentation/completion updates

**Files:**
- Modify: `VERSION`
- Modify: `bin/codex-auth`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `completions/codex-auth.bash`
- Modify: `tests/smoke.sh`

- [ ] Bump to `0.9.0`.
- [ ] Document `codex-auth cron`, setup examples, log path, and delete flow.
- [ ] Update completions for cron subcommands and flags.
- [ ] Run `bash -n install.sh`, `bash -n tests/smoke.sh`, and `bash tests/smoke.sh`.
