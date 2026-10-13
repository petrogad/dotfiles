# Agent instructions

Agent-agnostic standing instructions — the single source of truth for every agent, and the only
place these belong. Codex reads this file natively at `~/.agents/AGENTS.md`; Claude Code reads
`~/.claude/CLAUDE.md`, which `make agents` symlinks straight at this file, so both see the same
words with no copy to drift. Add standing instructions here, not in either agent's own config. Grow
this over time.

## References

If I ask you to read a reference or file, URL, issue, ticket, or ANY document and you are not able to retrieve it, TELL ME so we can fix the issue. Do not just ignore or work without the reference material.

## Work-management docs

Research, plans, handoffs, and reviews are work management, not code. They live under
`$AGENT_WORK_DIR` (`~/agents`) and are **never** written into a repo or committed. One-off scripts,
utilities, and diagrams go in `$AGENT_WORK_DIR/artifacts` rather than being left loose in a repo.

Before creating or updating any of these, load the **`agent-docs`** skill for the shared conventions
(dirs, metadata block, status vocab, filenames, archive lifecycle) — including when writing one
adhoc, without going through `research` / `plan` / `handoff` / `pickup`. If a project-specific doc
skill scopes the area you're working in, it wins.

## Decision points

**When you have to guess at something only I can settle, proceed under your best assumption and say
what you assumed.** The test is whether I could still change my mind later and whether it would
cost something if I never found out — a timeout value you invented, a spec that contradicted itself
and you picked a reading, a fix you deliberately scoped out.

**Ask me directly whenever I am here and responsive.** Guess-and-flag is for decisions made *in my
absence*, mid-way through a long autonomous run. Flag each one in your final summary (and in the
handoff doc, if there is one), with the alternative and the cost of switching: a decision I can
reverse in one command is a different thing from one I cannot.
