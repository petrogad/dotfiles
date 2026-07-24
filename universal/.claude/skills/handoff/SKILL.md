---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: 'What will the next session be used for?'
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to `$AGENT_HANDOFF_DIR` (`~/agents/handoffs`) if set, otherwise `/private/tmp` on macOS or `/tmp` on Linux.

## Filename

Use a descriptive kebab-case name: `<topic>-handoff.md` (e.g. `forum-concealment-handoff.md`). If the work is tied to a tracking issue, prefix with the issue key: `<ISSUE-KEY>-<topic>-handoff.md`.

## Document structure

Start every handoff with a YAML-style metadata block so the next agent (or you) can orient at a glance:

```markdown
# <Title>

| Field       | Value |
|-------------|-------|
| Date        | YYYY-MM-DD |
| Repo        | <org>/<repo-name> |
| Branch      | <branch or worktree branch> |
| Worktree    | <path if in a worktree, otherwise "n/a"> |
| PR          | <URL if one exists, otherwise "none yet"> |
| Base        | <base branch, e.g. master/main> |
```

Populate from the current git state — run `git rev-parse`, `git branch --show-current`, check `.git` for worktree info, and `gh pr view --json url` if a PR is open.

## Content guidelines

A handoff is direct "how to pick up this task" instructions. Include:

1. **Context** — one paragraph on what was being done and why.
2. **Current state** — what's done, what's in progress, what's broken. Reference commits or diffs rather than re-describing code.
3. **Next steps** — ordered list of what the next session should do.
4. **Open questions / blockers** — anything unresolved that needs a decision.
5. **Key files** — paths the next agent will need to touch or read.
6. **Suggested skills** — skills the next agent should invoke to continue (e.g. `/work-item`, `/plan-to-work-items`).

## Principles

- **Reference, don't duplicate.** Do not inline content from PRs, plans, specs, or commits. Link by path or URL. Plans belong in `$AGENT_PLANS_DIR` (`~/agents/plans/`), research in `$AGENT_RESEARCH_DIR` (`~/agents/research/`) — reference those paths rather than inlining their content.
- **Worktree-aware.** If working in a git worktree, note the worktree path and branch so the next session can `cd` straight there or re-enter it.
- **Compact.** A handoff should be under 80 lines. If it's longer, you're inlining too much.
- **Redact secrets.** Strip API keys, tokens, passwords, or PII.
- **Defer to project skills.** If a project-specific skill dictates handoff location or format, follow it instead of these defaults.

## Arguments

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the document accordingly — emphasize the relevant context and prune the rest.
