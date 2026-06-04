# Touch Cron Design

## Goal

Add a friendly `codex-auth cron` command group that manages scheduled `codex-auth touch` runs for saved Codex auth profiles.

## Command shape

- `codex-auth cron` / `codex-auth cron list`: list codex-auth-managed touch cron jobs.
- `codex-auth cron setup`: interactive wizard for creating a managed touch cron job.
- `codex-auth cron add`: non-interactive creation path with flags such as `--time HH:MM`, `--all`, `--profile NAME`, `--daily`, `--schedule "MIN HOUR DOM MON DOW"`, and `--yes`.
- `codex-auth cron delete [JOB_ID|--all] [--yes]`: remove managed jobs only.
- `codex-auth cron run JOB_ID (--all|PROFILE)`: cron-facing runner that prints timestamped start/end lines and invokes the existing touch implementation.

## Managed crontab model

The tool edits only blocks wrapped in comments like:

```cron
# BEGIN codex-auth touch daily-0830-all
# schedule: daily at 08:30
# target: --all
# log: /home/user/.codex/accounts/cron/touch.log
30 8 * * * PATH=/path/to/codex-bin:/usr/local/bin:/usr/bin:/bin /abs/path/to/codex-auth cron run daily-0830-all --all >> /home/user/.codex/accounts/cron/touch.log 2>&1
# END codex-auth touch daily-0830-all
```

Listing and deletion parse these markers, preserving unrelated user crontab entries. Setup/add use a simple lock under `~/.codex/accounts/cron.lock` to avoid concurrent read-modify-write races.

## Wizard UX

The wizard lists existing managed jobs first, then asks. In interactive terminals, target and schedule choices use `whiptail` when available; otherwise the wizard falls back to colored numbered prompts with readline-style editing where Bash supports it.

1. Target: all profiles by default, or one profile selected with the same fzf/numeric style as `switch`.
2. Schedule: daily at a time by default, or a custom five-field cron expression.
3. Time: 24-hour `HH:MM` for daily schedules.
4. Confirmation: show the five cron fields, touch command, cron runner command, and log path before installing.

## Logging

The crontab line redirects all output to `~/.codex/accounts/cron/touch.log`. `cron run` adds timestamped start/end lines so the log remains readable around existing `touch` output.

## Versioning

This is a new user-visible command group, so the release should be `0.9.0`.
