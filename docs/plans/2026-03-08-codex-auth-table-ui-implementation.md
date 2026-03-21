# Codex Auth Table UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve `codex-auth` so `list` prints a readable table, `switch` uses a tmux-friendly `fzf` selector by default in interactive terminals, and bash autocomplete is available for commands and profile names.

**Architecture:** Extend the existing bash script with a structured row formatter that can emit tab-separated fields for `column` and richer preview lines for `fzf`. Keep `fzf` as the primary interactive selector, add tmux-aware flags when `$TMUX` is present, and add a separate bash completion script sourced from `.bashrc`.

**Tech Stack:** Bash, Python 3 stdlib helpers, `fzf`, `column`, bash completion.

---

### Task 1: Add failing tests for table output and completion assets

**Files:**
- Modify: `/home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
- Create: `/home/fasand/Developer/reference-architecture/bin/codex-auth.bash`

**Step 1: Write the failing test**
Add tests that expect `codex-auth list` to output a table header and aligned tabular content, and that the bash completion file exists and exposes profile-name completion behavior.

**Step 2: Run test to verify it fails**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: FAIL because the current output is pipe-delimited and no completion script exists.

**Step 3: Write minimal implementation**
Create the completion file and scaffold table-oriented output helpers.

**Step 4: Run test to verify it passes**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: PASS for header/completion presence checks.

### Task 2: Implement formatted table output

**Files:**
- Modify: `/home/fasand/Developer/reference-architecture/bin/codex-auth`
- Modify: `/home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`

**Step 1: Write the failing test**
Assert that `list` includes columns like `ACTIVE`, `PROFILE`, `EMAIL`, `5H`, and `WEEKLY`, and that active/inactive rows are rendered cleanly.

**Step 2: Run test to verify it fails**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: FAIL on old list formatting.

**Step 3: Write minimal implementation**
Emit TSV rows, pipe them through `column`, and keep backend-preferred 5h/weekly values.

**Step 4: Run test to verify it passes**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: PASS for list readability checks.

### Task 3: Make `switch` reliably use arrow-key fzf in tmux

**Files:**
- Modify: `/home/fasand/Developer/reference-architecture/bin/codex-auth`
- Modify: `/home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`

**Step 1: Write the failing test**
Add a test path that forces fzf selection non-interactively and verifies `switch` chooses the intended profile via the fzf branch.

**Step 2: Run test to verify it fails**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: FAIL because the current test harness cannot force the fzf path.

**Step 3: Write minimal implementation**
Add a small test-only force flag/environment override, tmux-aware `fzf --tmux` behavior, and keep numbered fallback for true non-interactive contexts.

**Step 4: Run test to verify it passes**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: PASS for fzf selection behavior.

### Task 4: Wire bash completion in `.bashrc`

**Files:**
- Modify: `/home/fasand/.bashrc`
- Create: `/home/fasand/Developer/reference-architecture/bin/codex-auth.bash`

**Step 1: Write the failing test**
Add a shell check that sources `.bashrc` and confirms the completion file is loaded without errors.

**Step 2: Run test to verify it fails**
Run: `bash -ic 'source ~/.bashrc >/dev/null 2>&1; complete -p codex-auth'`
Expected: FAIL until completion is wired.

**Step 3: Write minimal implementation**
Source the completion script from `.bashrc` if present, without duplicate sourcing problems.

**Step 4: Run test to verify it passes**
Run: `bash -ic 'source ~/.bashrc >/dev/null 2>&1; complete -p codex-auth'`
Expected: shows the completion registration.

### Task 5: Final verification

**Files:**
- Review: `/home/fasand/Developer/reference-architecture/bin/codex-auth`
- Review: `/home/fasand/Developer/reference-architecture/bin/codex-auth.bash`
- Review: `/home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
- Review: `/home/fasand/.bashrc`

**Step 1: Syntax check**
Run: `bash -n /home/fasand/Developer/reference-architecture/bin/codex-auth /home/fasand/Developer/reference-architecture/bin/codex-auth.bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: PASS.

**Step 2: Full test run**
Run: `bash /home/fasand/Developer/reference-architecture/tests/test_codex_auth.sh`
Expected: PASS.

**Step 3: Interactive smoke check**
Run: `codex-auth list` and `codex-auth switch`
Expected: readable table output and fzf selector in interactive tmux terminals.
