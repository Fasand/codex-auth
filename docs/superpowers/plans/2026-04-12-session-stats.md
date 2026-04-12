# Session Statistics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add global historical Codex session usage statistics, exposed via `codex-auth stats` with a `statistics` alias and a compact `list` footer summary.

**Architecture:** Keep the CLI Bash-first, but implement the statistics parsing/aggregation/rendering in embedded Python helpers inside `bin/codex-auth`. Parse rollout JSONL token events from `~/.codex/sessions`, aggregate them into calendar-aligned windows, fetch/cache official pricing from the OpenAI pricing docs page, and render concise terminal tables.

**Tech Stack:** Bash, Python 3 stdlib, existing shell smoke tests

---

## File structure
- Modify: `bin/codex-auth` — add stats command parsing, session aggregation/pricing/rendering helpers, list footer
- Modify: `completions/codex-auth.bash` — add `stats`, `statistics`, and `--period` completions
- Modify: `README.md` — document the new command and session statistics behavior
- Modify: `VERSION`, `CHANGELOG.md`, `tests/smoke.sh` — version bump and coverage
- Create: `docs/superpowers/specs/2026-04-12-session-stats-design.md`
- Create: `docs/superpowers/plans/2026-04-12-session-stats.md`

## Tasks
- [ ] Add command/help/version/documentation scaffolding for `stats`/`statistics`
- [ ] Implement session event parsing from rollout JSONL files
- [ ] Implement period/window aggregation and text rendering for footer + full stats output
- [ ] Implement pricing fetch/cache/parser from the official OpenAI pricing docs page
- [ ] Wire list footer + stats command together
- [ ] Extend completions and README examples
- [ ] Add smoke fixtures/tests for session stats and pricing fallback behavior
- [ ] Run bash syntax checks and full smoke tests
