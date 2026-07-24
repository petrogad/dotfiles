---
name: work-item
description: Pick up the next available work item from ready-work and start implementing it. Specify an initiative name (e.g., "community-tiers") or omit to auto-select.
disable-model-invocation: true
---

Pick up and start implementing the next available work item from `$AGENT_READY_WORK_DIR` (`~/agents/ready-work/`).

# Work Item Skill

## Input

The user provides either:
- An initiative name (e.g., `community-tiers`) to scope work selection
- Nothing, in which case scan all initiatives for available work

## Workflow

### Step 1: Find Available Work

1. Read `$AGENT_READY_WORK_DIR/_setup.md` for worktree workflow rules, repo locations, and build/test commands
2. If an initiative was specified, read `$AGENT_READY_WORK_DIR/{initiative}/README.md`
3. Otherwise, read `$AGENT_READY_WORK_DIR/README.md` and scan all initiative READMEs
4. Find work items by scanning the repo subfolders (one subfolder per repo)
5. A work item is **available** if ALL of these are true:
   - Its status line does NOT contain `DONE`, `IN PROGRESS`, or `BLOCKED`
   - It is not blocked by dependencies (check the `Depends on:` line)
   - It has the lowest available number prefix (01 before 02 before 03, etc.)
6. Among available items at the same dependency level, pick the first alphabetically

### Step 2: Present the Work Item for Confirmation

If an available item is found:

1. Read the full work item file
2. Present a summary to the user:
   - Item ID and title
   - Which repo and service it targets
   - Brief description of what will be done
   - Scope (small/medium/large)
   - Any dependencies or context worth noting
3. Ask the user to confirm: **Start this item, or skip to the next one?**
4. If the user skips, move to the next available item and repeat
5. If the user confirms, mark the status: `**Status:** IN PROGRESS` and proceed

If NO available item is found:

1. Report "No available work items" and explain why:
   - All items done?
   - Remaining items blocked? On what?
   - Waiting on external dependency?
2. Stop here. Do not proceed.

### Step 3: Set Up Worktree

Follow `$AGENT_READY_WORK_DIR/_setup.md` exactly:

1. `cd` to the repo root (path listed in `_setup.md`)
2. If the work item specifies an existing branch/worktree, `cd` into it
3. Otherwise, run `_worktree {branch-name}` to create a new one (or the command documented in `_setup.md`, if it specifies a different workflow)
4. `cd` into the worktree directory

### Step 4: Implement

1. Read the work item's **Work** section for specific steps
2. Follow the work item's instructions precisely
3. Look at existing patterns in the codebase before writing new code
4. Run the repo's build command (from `_setup.md`) to verify compilation
5. Run the relevant unit tests (commands in `_setup.md`) to verify correctness

### Step 5: Self-Review (Principal Engineer Lens)

Before reporting completion, review your own changes as a principal engineer would. Check each of these:

**Conventions:**
- Does the code follow the patterns already established in this repo?
- Are naming conventions consistent with surrounding code (not just "correct in isolation")?
- Does it match the style of the file it lives in (spacing, organization, access modifiers)?

**Performance:**
- Are there unnecessary allocations on hot paths?
- Could an async call be parallelized with existing work?
- Are you making N+1 calls where a batch call exists?
- Is there a caching layer you should be reading from instead of calling a service?

**DRY / Reuse:**
- Is there an existing utility, helper, or extension method that already does what you wrote?
- Are you duplicating an enum, constant, or type that lives elsewhere in the repo?
- If you extracted a helper, is it genuinely reusable or just premature abstraction?

**Correctness:**
- Does fail-open vs fail-closed match the spec's intent?
- Are edge cases handled (null, zero, negative, empty collection)?
- Is the error handling appropriate for the call site (swallow vs propagate)?

If the review surfaces issues, fix them before proceeding. If something is uncertain (e.g., "should this be fail-open?"), note it as an open question rather than guessing.

### Step 6: Commit and Create Draft PR

Once self-review passes and build/tests are green:

1. Stage the changed files (be specific, don't `git add -A`)
2. Commit with a clear message: `ADHOC: {short description of what was done}`
3. Push the branch: `git push -u origin {branch-name}`
4. Create a **draft** PR: `gh pr create --draft --title "ADHOC: {title}" --body "..."`
   - Keep the description minimal and direct
   - Link to the relevant spec section(s) for context
   - Include a test plan checklist
   - NEVER use em dashes in PR descriptions
5. Update the work item file:
   - Change status to: `**Status:** DONE (Draft PR #{number})`
   - Add a `## Completed` section at the bottom with:
     - Draft PR link
     - Worktree path
     - Files changed (brief list)
     - Build result (pass/fail)
     - Test result (pass/fail, count)
     - Self-review findings (anything you fixed or flagged)
     - Open questions (if any)

Then tell the user the draft PR is ready for review.

## Key Rules

- Always create **draft** PRs, never regular PRs
- NEVER force push or push to master
- NEVER pick up an item marked IN PROGRESS (another agent is on it)
- If build or tests fail, try to fix. If stuck, report the failure and stop.
- Always read `_setup.md` before starting
