# codex-auth

Manage multiple ChatGPT Codex `auth.json` profiles from the command line.

`codex-auth` is a small, practical utility for saving, switching, listing, and refreshing multiple Codex login profiles. It is vibe-coded in the best sense: built quickly, kept useful, and polished enough to share.

## What it does

- Save the current Codex auth snapshot as a named profile
- Switch between saved profiles
- List profiles with cached usage information
- Refresh live usage data for one or all profiles
- Add Bash completion support for common commands and saved profile names

## Requirements

- Bash
- Python 3
- The `codex` CLI already installed and working
- `column` for table formatting (usually available by default)
- Optional: `fzf` for nicer interactive profile switching
- Optional: `curl` for no-clone installs via `install.sh --from ...`

## Install

### From a local checkout

```bash
./install.sh
```

This installs:

- `codex-auth` to `~/.local/bin/codex-auth`
- Bash completions to `~/.local/share/bash-completion/completions/codex-auth`

You can change the destination with `--prefix`, `--bin-dir`, `--completion-dir`, or skip completions entirely with `--skip-completions`.

### Without cloning the repo

Once this repository is published, you can install it directly from the raw files:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/main/install.sh) \
  --from https://raw.githubusercontent.com/Fasand/codex-auth/main
```

## Update

Re-run the same install command you used originally.

Examples:

```bash
./install.sh
```

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/main/install.sh) \
  --from https://raw.githubusercontent.com/Fasand/codex-auth/main
```

## Usage

```bash
codex-auth list
codex-auth current
codex-auth save work
codex-auth switch work
codex-auth refresh-usage --all
```

Run `codex-auth help` for the full command reference.

## Bash completions

The repo includes `completions/codex-auth.bash`, which enables tab completion for:

- top-level commands such as `list`, `switch`, and `refresh-usage`
- saved profile names read from `~/.codex/accounts/profiles`
- `--all` for `refresh-usage`

If your shell does not auto-load completions from the installed directory, add this to `~/.bashrc`:

```bash
source "$HOME/.local/share/bash-completion/completions/codex-auth"
```

## Notes

- Profiles are stored under `~/.codex/accounts/profiles`
- The active auth file remains `~/.codex/auth.json`
- Usage refresh talks to ChatGPT Codex usage endpoints using the saved auth token
- This project is intentionally small and practical; the code favors usefulness over ceremony

## License

MIT
