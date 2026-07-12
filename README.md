# codex-auth

Manage multiple ChatGPT Codex `auth.json` profiles from the command line.

`codex-auth` is a small, practical utility for saving, switching, listing, and refreshing multiple Codex login profiles. It is vibe-coded in the best sense: built quickly, kept useful, and polished enough to share.

Current version: `0.10.1`

See [CHANGELOG.md](CHANGELOG.md) for release history.

## What it does

- Save the current Codex auth snapshot as a named profile
- Switch between saved profiles
- List profiles with cached usage information
- Optionally show a compact global session-usage footer in `list`
- Inspect historical local session statistics with `stats`
- Refresh live usage data for one or all profiles, show progress while refreshing, and then print the updated list
- Inspect saved ID/access token expiration metadata with `token-status`
- Touch one or all profiles with a minimal Codex request, save the live auth snapshot, and report whether Codex rotated the tokens
- Set up, list, and delete managed cron jobs that run scheduled profile touches
- Update the installed CLI without cloning the repository
- Add Bash completion support for common commands and saved profile names

## Prerequisites

These must already exist before `codex-auth` is usable:

- Bash
- The `codex` CLI installed and working

## Installer-managed dependencies

The installer can check for and, on supported systems, best-effort install these dependencies:

- `python3` for the utility's JSON and network helpers
- `curl` for no-clone installs and updates
- `fzf` for the nicer interactive profile picker
- Bash completion support for auto-loading completions

Notes:

- `install.sh --install-deps` currently supports Homebrew, `apt-get`, `dnf`, and `pacman`.
- The installer does **not** install the `codex` CLI for you.

## Install

### Fast install from GitHub

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/main/install.sh)
```

If dependencies are missing, the installer will report them and, in an interactive shell, offer to install supported ones.

### Local checkout install

```bash
./install.sh
```

This installs:

- `codex-auth` to `~/.local/bin/codex-auth`
- Bash completions to `~/.local/share/bash-completion/completions/codex-auth`

You can change the destination with `--prefix`, `--bin-dir`, `--completion-dir`, or skip completions entirely with `--skip-completions`.

## Dependency checks

Check the current machine without installing anything:

```bash
./install.sh --check-deps
```

`--check-deps` prints a short status view with green/red indicators so you can quickly see what is available and what is missing.

Install supported dependencies non-interactively:

```bash
./install.sh --install-deps
```

Remote install plus dependency installation:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/main/install.sh) --install-deps
```

## Update

You have two supported update options:

1. Run the built-in updater:

```bash
codex-auth update
```

2. Re-run the install command directly:

Examples:

```bash
./install.sh
```

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/main/install.sh)
```

Existing installations continue to update in place; you do not need to remove anything first.

### Automatic update check

Installed copies check for a new version at most once per day: the first interactive command of the day fetches the tiny `VERSION` file from the raw GitHub base (2s connect / 4s total budget) and, if a newer release exists, asks `Update now? [Y/n]`. Pressing Enter updates immediately and skips the command you were running — re-run it afterwards. Declining continues normally and stays quiet until the next day's check.

The check never runs for scripts, pipes, or cron jobs (interactive terminals only), never in a local git checkout, and any failure — offline, timeout, missing `curl` — silently skips the check without affecting your command. Failed attempts are cached too, so an offline machine pays the timeout at most once per day.

- `CODEX_AUTH_NO_UPDATE_CHECK=1` disables the check entirely.
- `CODEX_AUTH_UPDATE_CHECK_TTL_SECONDS` overrides the once-per-day interval (default `86400`).

## Install a specific tagged version

The repository keeps retained release tags so you can install specific historical versions when needed. Use the same raw GitHub pattern, but replace `main` with a tag such as `0.3.0`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/0.3.0/install.sh) \
  --from https://raw.githubusercontent.com/Fasand/codex-auth/0.3.0
```

You can also install any other retained tag the same way:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/<tag>/install.sh) \
  --from https://raw.githubusercontent.com/Fasand/codex-auth/<tag>
```

For older `0.x` release lines, the repo keeps the `0.x.0` tag and the latest patch tag from that line.

## Custom sources and forks

By default, the installer downloads from this repository's `main` branch. If you are testing a fork or a different raw file base, override it with `--from` or `CODEX_AUTH_INSTALL_FROM`.

`codex-auth update` also respects `CODEX_AUTH_INSTALL_FROM`, so advanced users can point self-update at an alternate raw base without cloning the repository.

Examples:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/main/install.sh) \
  --from https://raw.githubusercontent.com/someone/codex-auth/main
```

```bash
CODEX_AUTH_INSTALL_FROM=file:///path/to/codex-auth ./install.sh
```

## Usage

```bash
codex-auth list
codex-auth list --utc
codex-auth list --with-stats
codex-auth current
codex-auth current --utc
codex-auth save work
codex-auth switch work
codex-auth refresh-usage
codex-auth refresh work --with-stats
codex-auth token-status
codex-auth token-status work --utc
codex-auth touch work
codex-auth touch --all
codex-auth cron
codex-auth cron setup
codex-auth cron add --time 08:30 --yes
codex-auth cron delete
codex-auth stats
codex-auth stats --period 7d
codex-auth stats --recompute
codex-auth update
codex-auth --version
```

Run `codex-auth help` for the full command reference.

### Timezone display

- `list`, `current`, `refresh-usage`, and `refresh` display reset/check timestamps in your local timezone by default.
- Pass `--utc` to any of those commands if you want the older UTC-style output.
- If a local timezone cannot be determined, the CLI falls back to UTC.

### Refresh behavior

- `codex-auth refresh-usage` and `codex-auth refresh` refresh **usage data** from ChatGPT Codex usage endpoints. They do not perform a Codex OAuth token refresh by themselves.
- `codex-auth refresh-usage` or `codex-auth refresh` with no profile name refreshes every saved profile directly, same as `--all`.
- Percentages prefixed with `~` are approximate: they were backfilled from the latest local Codex session snapshot (recent rollouts only) or fetched from the fallback usage endpoint, rather than coming straight from the primary usage endpoint.
- Multi-profile refreshes show progress as each profile is processed; interactive terminals use a single live-updating line, while non-interactive output stays line-based.
- If one or more profiles fail to refresh, the command still finishes the rest of the batch, prints the updated profile list, and then summarizes the failures before exiting non-zero.
- Refresh prints the updated profile list quickly by default. Pass `--with-stats` if you also want the slower local-session usage footer after the refresh.

### Token status and touch

- `codex-auth token-status [profile|--all]` shows saved ID-token and access-token expirations, last refresh time, and whether a refresh token is present. With no profile name, it lists all saved profiles.
- `codex-auth touch <profile>|--all` switches to each target profile, runs a minimal non-interactive `codex exec` prompt in a temporary empty directory, saves the live `auth.json` back to that profile, reports whether the ID/access tokens actually changed, and then restores the profile that was active before the touch.
- The touch command uses `--ephemeral`, `--ignore-user-config`, `--ignore-rules`, `--skip-git-repo-check`, and a read-only sandbox to keep the request small and avoid loading MCP/user/project customizations.
- Codex does not necessarily rotate tokens on every touch. If the current access token is still acceptable to Codex, `touch` can complete successfully and report that tokens were unchanged.
- Touching profiles consumes a small amount of Codex usage because it sends a real request.

### Scheduled touch cron jobs

- The cron commands require a working user `crontab` command on the machine where you schedule the job.
- `codex-auth cron` or `codex-auth cron list` shows cron jobs managed by this tool.
- `codex-auth cron setup` starts an interactive wizard. It lists existing managed jobs, asks whether to touch all profiles or one profile, asks for a daily or custom schedule, previews the exact cron fields and command, and then asks for confirmation. If `whiptail` is available in an interactive terminal, the wizard uses that dialog UI; otherwise it falls back to colored numbered prompts with readline-style editing where Bash supports it.
- `codex-auth cron add --time 08:30 --yes` installs a daily scheduled `touch --all` job without prompts.
- `codex-auth cron add --time 07:15 --profile work --yes` schedules a single profile every day.
- `codex-auth cron add --schedule "30 8 * * 1,3,5" --yes` uses a custom cron expression, such as Monday/Wednesday/Friday at 08:30.
- `codex-auth cron delete` lets you choose a managed job to remove; `codex-auth cron delete --all --yes` removes every codex-auth-managed touch job.
- Cron entries are wrapped in `# BEGIN codex-auth touch ...` / `# END codex-auth touch ...` markers, so delete/list operations only manage jobs created by `codex-auth`.
- Scheduled touch output is appended to `~/.codex/accounts/cron/touch.log` by default. The cron runner prints timestamped start/end lines around the normal `touch` output.
- Generated jobs call `codex-auth cron run ...` instead of `touch` directly so logs include the managed job id, start/end timestamps, and final exit status without making the crontab line itself more complex.
- If you use a non-default `CODEX_HOME`, the generated cron command preserves it. The generated command also sets a minimal `PATH` containing the resolved `codex` executable's directory, which helps cron run `codex` installations from tools like `nvm` without depending on your interactive shell startup files.
- Set `CODEX_AUTH_DISABLE_WHIPTAIL=1` if you prefer the plain numbered cron setup prompts even when `whiptail` is installed.

### Session statistics

- `codex-auth list --with-stats` adds a compact two-line footer with global local-session usage for **today** and **7d** when rollout history exists.
- `codex-auth refresh-usage --with-stats` and `codex-auth refresh --with-stats` include that same footer after refreshing and listing profiles.
- `codex-auth stats` is the primary command for historical usage; `codex-auth statistics` is an alias.
- The stats view always shows overview columns for `today`, `7d`, `14d`, `30d`, and `all`, then focuses the daily/model breakdown on `30d` by default.
- Use `--period today|7d|14d|30d|all` to change that deeper focus, and `--utc` to use UTC day boundaries instead of local time.
- Parsed rollout-session data is cached under `~/.codex/accounts/session-stats-cache.json` by default. Unchanged session files are reused on later `stats`/`--with-stats` runs, while changed files are reparsed automatically.
- Pass `codex-auth stats --recompute` to ignore and rewrite the session stats cache.
- Estimated cost is shown as **API-equivalent cost** based on cached official OpenAI pricing, not your actual ChatGPT subscription charge.

## Bash completions

The repo includes `completions/codex-auth.bash`, which enables tab completion for:

- top-level commands such as `list`, `switch`, `refresh-usage`, `refresh`, `token-status`, `touch`, `cron`, and `update`
- saved profile names read from `~/.codex/accounts/profiles`
- `--all`, `--utc`, `--with-stats`, `--period`, `--recompute`, and cron flags such as `--time`, `--schedule`, `--profile`, and `--yes` for the relevant commands

### Linux

If your shell does not auto-load completions from the installed directory, add this to `~/.bashrc`:

```bash
source "$HOME/.local/share/bash-completion/completions/codex-auth"
```

If you want system-provided Bash completion auto-loading, install your distro's `bash-completion` package.

### macOS

Bash completion auto-loading typically requires Homebrew's `bash-completion@2` package. Even without it, you can still source the installed completion file manually:

```bash
source "$HOME/.local/share/bash-completion/completions/codex-auth"
```

## Notes

- Profiles are stored under `~/.codex/accounts/profiles`
- The active auth file remains `~/.codex/auth.json`
- Usage refresh talks to ChatGPT Codex usage endpoints using the saved access token
- Saved profile metadata tracks both ID-token and access-token expirations
- Session statistics parse rollout JSONL files under `~/.codex/sessions`
- Pricing for session cost estimates is cached under `~/.codex/accounts/pricing-cache.json` for one week by default
- Parsed session statistics are cached under `~/.codex/accounts/session-stats-cache.json` by default
- Scheduled touch logs are written under `~/.codex/accounts/cron/touch.log` by default
- Terminal colors are enabled automatically on color-capable terminals and can be disabled with `NO_COLOR=1`
- This project is intentionally small and practical; the code favors usefulness over ceremony

## Smoke tests

- `tests/smoke.sh` exercises the version flag, dependency report, README-style installer path, reinstall/update behavior, timezone-aware list output, refresh/list workflows, touch behavior, and managed cron setup.
- GitHub Actions runs that smoke test on Ubuntu and macOS for pushes and pull requests.

## License

MIT
