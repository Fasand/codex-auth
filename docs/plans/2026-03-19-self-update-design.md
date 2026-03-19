# codex-auth Self-Update Design

## Summary
Add a new `codex-auth update` command that updates the installed CLI by downloading and executing the project installer from the default upstream source or from `CODEX_AUTH_INSTALL_FROM` when that environment variable is set.

## Goals
- Provide a first-class self-update command in the executable.
- Reuse the existing no-clone install path instead of cloning the repository.
- Respect the existing installer source override via environment variable.
- Preserve the current installation location when updating.

## Non-goals
- Adding a `--from` override to `codex-auth update`.
- Re-implementing installer logic inside the main executable.
- Cloning or checking out the repository during update.

## Chosen approach
`codex-auth update` will:
1. Resolve the installer base URL from `CODEX_AUTH_INSTALL_FROM`, falling back to the built-in default raw GitHub URL.
2. Determine the current executable path so the update can target the same install location.
3. Download `install.sh` from the resolved source.
4. Execute the installer with arguments that preserve the current binary destination and skip completions when they are not installed alongside the binary.

## Error handling
- Fail with a clear message if `curl` is unavailable.
- Fail with a clear message if the installer cannot be downloaded.
- Fail with a clear message if the running executable path cannot be resolved to a writable install target.

## Documentation impact
- Add `update` to the help text and README usage examples.
- Describe `codex-auth update` as one update option, alongside re-running the install script directly.
- Mention the environment-variable override behavior for custom update sources.

## Testing
- Add a smoke test that installs into a temporary prefix from a `file://` source override and then runs the installed `codex-auth update` command.
- Extend docs/help/completion tests to cover the new command and update wording.
