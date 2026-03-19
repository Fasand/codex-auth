# codex-auth

Small CLI for saving, switching, listing, and refreshing multiple ChatGPT Codex auth profiles.

## Working rules

- Do not work directly on `main`.
- Start from an up-to-date `main`, then create a short branch such as `feat/<slug>`, `fix/<slug>`, `docs/<slug>`, or `chore/<slug>`.
- Slash-style branch names like `feat/<slug>` work normally; in sandboxed Codex sessions, branch creation may need elevated Git permissions because Git must write under `.git/refs`.
- Leave changes uncommitted by default and wait for the user to explicitly say to continue before committing, pushing, or opening a PR.
- For GitHub-related operations in Codex sessions, prefer the locally authenticated command-line tools over connector/integration actions because the local CLI auth is the source of truth for the correct user and permissions.
- Open a PR for every change.
- Every PR should include a short self-test command that installs from that exact branch, for example:
  - `bash <(curl -fsSL https://raw.githubusercontent.com/Fasand/codex-auth/<branch>/install.sh) --from https://raw.githubusercontent.com/Fasand/codex-auth/<branch> --prefix "$HOME/.local/codex-auth-pr-test"`
- Keep the README install instructions current whenever install behavior changes.

## Versioning

- Bump the version for every meaningful change.
- Patch (`0.0.x`) for small fixes, doc/process updates, and minor installer changes.
- Minor (`0.x.0`) for new user-visible features or notable behavior changes.
- Update version references consistently in `VERSION`, `bin/codex-auth`, README, changelog, and any tests that pin the current version.

## Changelog

- Maintain `CHANGELOG.md` newest-first.
- Append each new release at the top.
- Format each entry as `## x.y.z - YYYY-MM-DD` followed by brief bullets describing release-level changes.
- Track version bumps, not every individual commit.

## Verification

- Before finishing, run at least:
  - `bash -n install.sh`
  - `bash -n tests/smoke.sh`
  - `bash tests/smoke.sh`
- PR checks should run on the PR itself; pushes to `main` validate post-merge.
