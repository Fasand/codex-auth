# codex-auth

Manage multiple ChatGPT Codex `auth.json` profiles from the command line.

`codex-auth` is a small, practical utility for saving, switching, listing, and refreshing multiple Codex login profiles. It is vibe-coded in the best sense: built quickly, kept useful, and polished enough to share.

## What it does

- Save the current Codex auth snapshot as a named profile
- Switch between saved profiles
- List profiles with cached usage information
- Refresh live usage data for one or all profiles
- Add shell completion support for common commands and profile names

## Requirements

- Bash
- Python 3
- The `codex` CLI already installed and working
- `column` for table formatting (usually available by default)
- Optional: `fzf` for nicer interactive profile switching

## Usage

```bash
codex-auth list
codex-auth current
codex-auth save work
codex-auth switch work
codex-auth refresh-usage --all
```

Run `codex-auth help` for the full command reference.

## Notes

- Profiles are stored under `~/.codex/accounts/profiles`
- The active auth file remains `~/.codex/auth.json`
- Usage refresh talks to ChatGPT Codex usage endpoints using the saved auth token
- Bash completion support is included in this repo

## License

MIT
