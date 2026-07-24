---
name: plan-to-work-items
description: Break a plan into numbered, dependency-ordered work items organized by initiative and repo, ready for parallel agent execution.
disable-model-invocation: true
---

Convert a plan document into actionable work items in `$AGENT_READY_WORK_DIR` (`~/agents/ready-work/`). Use when you have a finalized plan (in `$AGENT_PLANS_DIR`, `~/agents/plans/`) and want to generate agent-ready task files that can be picked up by worktree-isolated agents.

# Plan to Work Items

## Input

The user provides either:
- A path to a plan file (e.g., `$AGENT_PLANS_DIR/community-tiers-plan.md`)
- A plan name to look up in `$AGENT_PLANS_DIR`
- Or asks you to use the current/most recent plan

If no plan is specified, list plans in `$AGENT_PLANS_DIR` and ask which to use.

## Output Structure

```
$AGENT_READY_WORK_DIR/          (~/agents/ready-work/)
├── README.md                           (index of all initiatives)
├── _setup.md                           (shared worktree workflow — applies to all)
└── {initiative-name}/
    ├── README.md                       (task table with deps, repos, services)
    ├── {repo-1}/
    │   ├── 01a-{short-name}.md
    │   ├── 01b-{short-name}.md
    │   └── 02a-{short-name}.md
    └── {repo-2}/
        └── 04a-{short-name}.md
```

## Workflow

### Step 1: Read the Plan

Read the plan file. Identify:
- What's already completed (skip these)
- What's in progress (note blockers)
- What remains (these become work items)
- Dependencies between items
- Which repos and services each item touches

### Step 2: Determine Dependency Levels

Assign each remaining item a dependency number:

| Level | Meaning |
|-------|---------|
| 01 | No dependencies — can start immediately |
| 02 | Depends on level 01 items or a blocking PR/merge |
| 03 | Depends on level 02 items |
| 04 | Depends on level 03 items or external events (deploys, coordination) |

Items at the same level with a letter suffix (01a, 01b, 01c) can run **in parallel**.

### Step 3: Research Each Work Item

For each remaining item, research the codebase to understand:
- Exact files that will be modified or created
- Existing patterns to follow (find similar code)
- Dependencies already available (NuGet packages, injected services, etc.)
- Potential merge conflicts with in-flight PRs

Use Explore agents or grep/find to gather this information. Do NOT guess — look at the actual code.

### Step 4: Write Work Item Files

Each work item file follows this template:

```markdown
# {ID}: {Title}

**Status:** Ready to start | Blocked on {blocker}
**Depends on:** {list dependencies or "None"}
**Plan:** [link to plan file]
**Branch:** {existing branch name} | Create new from master
**Repo:** `{repo-name}` — see [../../_setup.md](../../_setup.md) for worktree workflow
**Service:** {service-name within repo}
**Scope:** Small | Medium | Medium-Large | Large

## Objective

{1-2 sentences: what this achieves and why}

## Context

{Relevant background: what already exists, what patterns to follow, key constraints}

## Work

{Numbered steps — specific enough for an agent to execute without ambiguity}

## Files

{List of files to create or modify, with paths}

## Conflict Risk with In-Flight PRs

{Any known conflicts with open PRs — "None" if clean}

## Verification

{How to confirm the work is correct: tests, builds, manual checks}
```

### Step 5: Write the Initiative README

Create `{initiative}/README.md` with:
- Link to the plan
- Link to `_setup.md`
- Dependency level legend
- Table of all work items (ID, title, repo, service, scope)
- "Already Complete" section listing done items for context

### Step 6: Update Root README

Add or update the initiative entry in `$AGENT_READY_WORK_DIR/README.md`.

### Step 7: Verify Against Plan

**This step is mandatory.** Walk through each section of the plan and confirm:

1. **Coverage check:** Every "remaining" item in the plan has a corresponding work item file
2. **Dependency check:** No work item is marked "Ready" if its plan dependencies aren't met
3. **Repo check:** Each work item is in the correct repo subfolder
4. **Completeness check:** No completed items from the plan accidentally got a work item
5. **Conflict check:** File overlap between work items is documented

Present the verification as a checklist:

```
## Verification Against Plan

- [ ] All remaining plan items have work item files
- [ ] Dependency levels match plan's phasing/ordering
- [ ] Each item is in the correct repo folder
- [ ] No completed items regenerated as work items
- [ ] Cross-item file conflicts documented
- [ ] _setup.md is current for the repos involved
```

Fix any issues found before presenting the final output to the user.

## Important Constraints

- **Research before writing:** Always look at the actual codebase before writing work items. An agent picking up a task should not discover the file doesn't exist or the pattern is different.
- **One concern per file:** Each work item should be independently executable by a single agent in a single worktree.
- **No overlap:** Two work items should not modify the same file unless the conflict is explicitly documented and the later one depends on the earlier.
- **Specific, not vague:** "Wire Frost into CommunityTierRuleSet" is good. "Integrate QPP" is not.
- **Include verification:** Every item must have a way to prove it's done (test command, build command, or observable behavior).
- **Reference existing code:** If a pattern exists in the codebase, link to it. Agents should copy patterns, not invent new ones.

## Updating Existing Work Items

If `$AGENT_READY_WORK_DIR/{initiative}/` already exists:
- Ask the user if they want to regenerate from scratch or update in place
- When updating: move completed items to an `_archive/` subfolder (don't delete), update statuses, add new items
- When regenerating: clear and rebuild entirely

## Shared Setup (_setup.md)

If `$AGENT_READY_WORK_DIR/_setup.md` doesn't exist, create it by:
1. Checking the repo's git worktree layout (`git worktree list`)
2. Finding worktree-related shell functions/aliases
3. Documenting the naming convention from existing worktrees
4. Including build/test commands relevant to the repos involved

If it already exists, verify it covers the repos in this initiative and update if needed.
