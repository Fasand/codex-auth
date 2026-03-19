# codex-auth

Manage multiple ChatGPT Codex `auth.json` profiles from the command line.

`codex-auth` is a small, practical utility for saving, switching, listing, and refreshing multiple Codex login profiles. It is vibe-coded in the best sense: built quickly, kept useful, and polished enough to share.

Current version: `0.3.0`

See [CHANGELOG.md](CHANGELOG.md) for release history.

## What it does

- Save the current Codex auth snapshot as a named profile
- Switch between saved profiles
- List profiles with cached usage information
- Refresh live usage data for one or all profiles
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

- `column` is optional. If it is missing, `codex-auth list` falls back to a plain aligned table.
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
codex-auth current
codex-auth save work
codex-auth switch work
codex-auth refresh-usage --all
codex-auth update
codex-auth --version
```

Run `codex-auth help` for the full command reference.

## Bash completions

The repo includes `completions/codex-auth.bash`, which enables tab completion for:

- top-level commands such as `list`, `switch`, `refresh-usage`, and `update`
- saved profile names read from `~/.codex/accounts/profiles`
- `--all` for `refresh-usage`

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
- This project is intentionally small and practical; the code favors usefulness over ceremony

## Smoke tests

- `tests/smoke.sh` exercises the version flag, dependency report, README-style installer path, reinstall/update behavior, and the `list` fallback when `column` is missing.
- GitHub Actions runs that smoke test on Ubuntu and macOS for pushes and pull requests.

## License

MIT
