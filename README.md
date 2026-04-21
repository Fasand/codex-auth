# codex-auth

Manage multiple ChatGPT Codex `auth.json` profiles from the command line.

`codex-auth` is a small, practical utility for saving, switching, listing, and refreshing multiple Codex login profiles. It is vibe-coded in the best sense: built quickly, kept useful, and polished enough to share.

Current version: `0.6.0`

See [CHANGELOG.md](CHANGELOG.md) for release history.

## What it does

- Save the current Codex auth snapshot as a named profile
- Switch between saved profiles
- List profiles with cached usage information
- Optionally show a compact global session-usage footer in `list`
- Inspect historical local session statistics with `stats`
- Refresh live usage data for one or all profiles, show progress while refreshing, and then print the updated list
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

- `codex-auth refresh-usage` or `codex-auth refresh` with no profile name asks for confirmation before refreshing every saved profile.
- Multi-profile refreshes show progress as each profile is processed; interactive terminals use a single live-updating line, while non-interactive output stays line-based.
- If one or more profiles fail to refresh, the command still finishes the rest of the batch, prints the updated profile list, and then summarizes the failures before exiting non-zero.
- Refresh prints the updated profile list quickly by default. Pass `--with-stats` if you also want the slower local-session usage footer after the refresh.

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

- top-level commands such as `list`, `switch`, `refresh-usage`, `refresh`, and `update`
- saved profile names read from `~/.codex/accounts/profiles`
- `--all`, `--utc`, `--with-stats`, `--period`, and `--recompute` for the relevant commands

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
- Usage refresh talks to ChatGPT Codex usage endpoints using the saved auth token
- Session statistics parse rollout JSONL files under `~/.codex/sessions`
- Pricing for session cost estimates is cached under `~/.codex/accounts/pricing-cache.json` for one week by default
- Parsed session statistics are cached under `~/.codex/accounts/session-stats-cache.json` by default
- Terminal colors are enabled automatically on color-capable terminals and can be disabled with `NO_COLOR=1`
- This project is intentionally small and practical; the code favors usefulness over ceremony

## Smoke tests

- `tests/smoke.sh` exercises the version flag, dependency report, README-style installer path, reinstall/update behavior, timezone-aware list output, and refresh/list workflows.
- GitHub Actions runs that smoke test on Ubuntu and macOS for pushes and pull requests.

## License

MIT
