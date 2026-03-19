# Self-Update Command Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `codex-auth update` command that self-updates via the existing installer without cloning the repository.

**Architecture:** Keep update behavior centralized in `install.sh`. The CLI should only resolve the current install destination, fetch the installer from the standard raw source (or `CODEX_AUTH_INSTALL_FROM`), and invoke it with arguments that preserve the current install layout.

**Tech Stack:** Bash, curl, existing shell smoke tests

---

### Task 1: Add failing smoke tests for the new command

**Files:**
- Modify: `tests/smoke.sh`

**Step 1: Write the failing tests**
- Add a smoke test that expects `codex-auth help` to mention `update`.
- Add a smoke test that expects the Bash completion command list to include `update`.
- Add a smoke test that installs into a temp prefix and then runs `<prefix>/bin/codex-auth update`, expecting the binary to remain installed and executable.
- Add README assertions for update documentation mentioning both `codex-auth update` and the curl installer path.

**Step 2: Run test to verify it fails**
Run: `bash tests/smoke.sh`
Expected: FAIL because `update` is not implemented or documented yet.

### Task 2: Implement the CLI update command

**Files:**
- Modify: `bin/codex-auth`

**Step 1: Write minimal implementation**
- Add constants for the default installer base URL.
- Add `update` to the usage output.
- Implement a helper that resolves the current executable path and chooses installer arguments that preserve the current install layout.
- Implement `update_self` that requires `curl`, downloads `install.sh`, and executes it.
- Wire the command into argument parsing.

**Step 2: Run targeted verification**
Run: `bash tests/smoke.sh`
Expected: fewer failures, possibly still failing on docs/version/completions until remaining tasks are done.

### Task 3: Update completions and README

**Files:**
- Modify: `completions/codex-auth.bash`
- Modify: `README.md`

**Step 1: Make the docs/completion changes**
- Add `update` to completion suggestions.
- Update README usage and update sections to present `codex-auth update` as one supported option and the curl installer path as another.
- Note that `CODEX_AUTH_INSTALL_FROM` affects self-update as well.

**Step 2: Run targeted verification**
Run: `bash tests/smoke.sh`
Expected: docs/completion related failures resolved.

### Task 4: Bump version metadata and changelog

**Files:**
- Modify: `VERSION`
- Modify: `bin/codex-auth`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `tests/smoke.sh`

**Step 1: Update version references**
- Bump from `0.2.2` to `0.3.0` because this adds a new user-visible command.
- Add a new changelog entry at the top dated `2026-03-19`.
- Update tests that pin the version.

**Step 2: Run full verification**
Run:
- `bash -n install.sh`
- `bash -n tests/smoke.sh`
- `bash tests/smoke.sh`
Expected: all commands pass.

### Task 5: Final review and PR notes

**Files:**
- Modify as needed after verification

**Step 1: Review changed files**
Run: `git diff -- docs/plans/2026-03-19-self-update-design.md docs/plans/2026-03-19-self-update.md bin/codex-auth completions/codex-auth.bash README.md VERSION CHANGELOG.md tests/smoke.sh`
Expected: diff matches the approved design.

**Step 2: Prepare PR self-test command**
- Include a PR self-test command using the feature branch raw URLs once ready.
