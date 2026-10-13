---
name: review-issue-pr
description: Review the implementation of a GitHub issue from the current repository by resolving its linked pull request and corresponding local worktree, inspecting the full change and surrounding code, running relevant validation, and drafting prioritized feedback for the issue and implementor. Use when the user supplies an issue number and asks to review, assess, audit, or give feedback on its implementation or associated PR, especially when the implementation is checked out in another git worktree.
argument-hint: '<issue-number> [--post]'
---

# Review an Issue PR

Perform a read-only, evidence-based code review unless the user explicitly asks to post comments or modify code.

This is the issue-driven review: start from what the issue asked for and judge the PR against it.
For a review of a working diff with no issue behind it, use the agent's own diff review instead
(`/code-review` in Claude Code, `/review` in Codex).

## Inputs

Require an integer GitHub issue number. Treat the current git repository as the repository in scope. Support both a normal checkout and a bare repository used as a worktree coordinator. If the current directory is not in a GitHub-backed repository, stop and ask for the repository.

## Resolve the review target

1. Run this skill's `scripts/inspect_issue_context.sh <issue-number>` (it sits beside this `SKILL.md`) from any worktree or from the bare worktree-coordinator directory.
2. Read the issue body, labels, comments, and acceptance criteria. Separate explicit requirements from reasonable inferences.
3. Resolve the implementing PR in this order:
   - PRs returned in the script's `linked_prs` section.
   - A PR whose body explicitly closes or fixes the issue.
   - A PR whose branch, title, body, or commits refer to the issue and whose diff implements it.
4. Never select a PR solely because its number equals the issue number.
5. If several plausible open PRs remain, stop and ask the user which one to review. If one candidate is clearly the implementation, state the evidence supporting that choice.
6. Match the PR head branch or SHA to the `worktrees` section. Prefer the corresponding clean local worktree because it may contain relevant uncommitted review state. Do not switch branches in the user's current worktree.
7. If no matching worktree exists, review the PR patch and current repository contents. Do not create a worktree unless the user asks.

## Establish the change boundary

From the selected worktree, inspect:

- `git status --short` to distinguish PR changes from uncommitted local changes.
- The PR base and head SHAs from GitHub; fetch only if required and permitted by the environment.
- The committed diff using the merge base, normally `git diff <base>...<head>`.
- Uncommitted changes separately. Include them only if the user indicates they belong to the implementation; otherwise note and exclude them.
- PR description, commits, review discussion, checks, and linked issue context.

Do not assume the GitHub patch is complete when a corresponding worktree exists. Do not treat generated files, dependency locks, or snapshots as sufficient evidence without reviewing their source change.

## Review thoroughly

1. Build a requirement checklist from the issue.
2. Map each requirement to implementation and tests, recording missing or partial coverage.
3. Read every changed file, then inspect surrounding callers, interfaces, schemas, migrations, configuration, and tests needed to evaluate behavior.
4. Check correctness, regressions, error paths, boundary cases, compatibility, security, concurrency, performance, observability, and maintainability as relevant to the change.
5. Look for scope drift: behavior added without an issue requirement and requirements left unimplemented.
6. Run the narrowest relevant tests, linters, type checks, or build steps documented by the repository. Expand validation when risk warrants it. Do not claim a check passed unless it was run successfully.
7. Check repository instructions such as `AGENTS.md` and `CLAUDE.md` and apply them to the worktree under review.

Prioritize concrete defects over stylistic preferences. A finding must describe an observable failure, regression, security risk, or meaningful maintenance hazard. Include the triggering conditions and why the existing code or tests do not prevent it.

## Produce the review

Lead with findings, ordered by severity:

- `[P0]` release-blocking or catastrophic
- `[P1]` serious defect requiring correction
- `[P2]` normal defect worth fixing
- `[P3]` minor but actionable issue

For each finding include:

- a concise title;
- a precise file and line reference in the reviewed worktree;
- the affected scenario and impact;
- a specific correction direction without rewriting the implementation unless asked.

Then provide:

1. **Issue assessment** — implemented, partially implemented, or not implemented, with requirement coverage and scope drift.
2. **Validation** — commands run and results, plus anything not runnable.
3. **Feedback for the implementor** — a polished, ready-to-send message summarizing required changes and notable strengths. Do not include praise merely to soften findings.
4. **Open questions** — only decisions or ambiguities that materially affect acceptance.

If there are no findings, say so explicitly, but still report residual risks and validation gaps. Never imply that absence of findings proves correctness.

## Keeping the review

A one-pass review stays in the response. When it is long or will take more than one pass
(the author pushes fixes and you review again), also keep it under `$AGENT_WORK_DIR/reviews/`
following the `agent-docs` skill: `<KEY-or-PR>-<topic>-review.md`, `**Type:** review`, the
reviewed SHA in `**Last verified:**`, and each finding's state (open / addressed / withdrawn)
so a second pass doesn't raise resolved points again. Mark it `delivered` once the feedback is
posted.

## GitHub writes

Draft feedback by default. Post to an issue or PR only when the user explicitly requests posting. Before posting, restate the exact repository and issue or PR target. Preserve the full local review in the response even if the posted version is shorter.
