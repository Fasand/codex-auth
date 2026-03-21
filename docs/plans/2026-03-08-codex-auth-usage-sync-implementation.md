# Codex Auth Usage Sync Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update `codex-auth` so it tracks account usability with accurate 5h/weekly remaining values, matches Codex CLI more closely for the active account, and move the script into `~/Developer/reference-architecture/bin`.

**Architecture:** Keep profile storage in `~/.codex/accounts`, but move the executable into the tracked reference-architecture repo. Extend the script to merge backend usage snapshots with the latest session token-count snapshot for the active account, and render CLI-style output for the active profile while keeping honest backend-derived summaries for inactive profiles.

**Tech Stack:** Bash, Python 3 stdlib, Codex rollout JSONL parsing, backend usage endpoint, optional `fzf`.

---

### Task 1: Add failing tests for new usage semantics and new script location

**Files:**
- Create: `/home/fasand/Developer/reference-architecture/bin/codex-auth`
- Create: `/home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`

**Step 1: Write the failing test**
Add tests that expect:
- the tracked script path in `~/Developer/reference-architecture/bin`
- backend `used_percent` to render as CLI-style remaining for 5h/weekly
- active-profile output to include session-derived context-used and effective window

**Step 2: Run test to verify it fails**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: FAIL because the moved script and new usage formatting do not exist yet.

**Step 3: Write minimal implementation**
Copy the current script into the repo bin location and scaffold test helpers for backend and session fixtures.

**Step 4: Run test to verify it passes**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: partial PASS once moved location and basic behavior work.

### Task 2: Implement session snapshot parsing and CLI-style active display

**Files:**
- Modify: `/home/fasand/Developer/reference-architecture/bin/codex-auth`
- Modify: `/home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`

**Step 1: Write the failing test**
Add a fixture rollout JSONL with a `token_count` event and assert active output contains values like `53% used`, `258K window`, `5h 87%`, `weekly 5%`.

**Step 2: Run test to verify it fails**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: FAIL because session parsing and derived formatting are missing.

**Step 3: Write minimal implementation**
Parse the latest token-count event, derive display values, and merge them into active-profile rendering.

**Step 4: Run test to verify it passes**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: PASS for active CLI-style usage display.

### Task 3: Fix backend caching semantics for inactive profiles

**Files:**
- Modify: `/home/fasand/Developer/reference-architecture/bin/codex-auth`
- Modify: `/home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`

**Step 1: Write the failing test**
Add assertions that inactive profiles show cached backend-derived 5h/weekly remaining and reset timing instead of raw used percentages.

**Step 2: Run test to verify it fails**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: FAIL because old semantics still show raw used values.

**Step 3: Write minimal implementation**
Store derived remaining percentages and reset metadata in `usage.json` and render them for inactive profiles.

**Step 4: Run test to verify it passes**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: PASS for inactive profile usability display.

### Task 4: Update PATH and remove dependency on ~/.codex/bin

**Files:**
- Modify: `/home/fasand/.bashrc`
- Remove or leave unused: `/home/fasand/.codex/bin/codex-auth`

**Step 1: Write the failing test**
Add a shell check ensuring `command -v codex-auth` resolves to the repo bin location after sourcing `.bashrc`.

**Step 2: Run test to verify it fails**
Run: `bash -ic 'source ~/.bashrc >/dev/null 2>&1; command -v codex-auth'`
Expected: FAIL or wrong path until `.bashrc` is updated.

**Step 3: Write minimal implementation**
Add `~/Developer/reference-architecture/bin` to `PATH` without duplication and stop depending on `~/.codex/bin`.

**Step 4: Run test to verify it passes**
Run: `bash -ic 'source ~/.bashrc >/dev/null 2>&1; command -v codex-auth'`
Expected: `/home/fasand/Developer/reference-architecture/bin/codex-auth`

### Task 5: Final verification

**Files:**
- Review: `/home/fasand/Developer/reference-architecture/bin/codex-auth`
- Review: `/home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
- Review: `/home/fasand/.bashrc`

**Step 1: Run syntax and test checks**
Run: `bash -n /home/fasand/Developer/reference-architecture/bin/codex-auth /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: PASS.

**Step 2: Run the full test script**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: PASS.

**Step 3: Smoke test against the real Codex home**
Run: `codex-auth current`
Expected: active profile output with CLI-style usage when session snapshot is available, or a clear backend-only fallback otherwise.

**Step 4: Refresh real account cache**
Run: `codex-auth refresh-usage --all`
Expected: updated `usage.json` with fresh timestamps and derived remaining values.
