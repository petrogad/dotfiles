# Agent instructions

Agent-agnostic standing instructions — the single source of truth for every agent, and the only
place these belong. Codex reads this file natively at `~/.agents/AGENTS.md`; Claude Code doesn't, so
`~/.claude/CLAUDE.md` is a stub that imports it. Add standing instructions here, not in either
agent's own config. Grow this over time.

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

## My notes scratchpad

I keep a global scratchpad that shows up as a panel in my tmux sidebar, so anything written to it is
in front of me within a second wherever I am. It is for the thing noticed *in passing* — a bug in
another project, a follow-up that doesn't belong in this task, something worth my attention that
would otherwise be lost when this session ends.

**Write with the CLI, never by editing the file.**

```sh
agent-mgr note add "auth redirect drops ?next"
agent-mgr note add "flaky teardown in payments" --body -   # markdown body on stdin
agent-mgr note list                                        # index, open/done, id, title
agent-mgr note show --id=<id>
```

`note add` appends under a lock and assigns the note an id. Editing the markdown by hand is a
read-modify-write over a file several things write at once, so it can silently drop a note somebody
else added a moment earlier. If you must read it directly it lives at
`${XDG_DATA_HOME:-~/.local/share}/tmux-agent-mgr/notes.md`, but prefer `note list` / `note show`.

Body format is ordinary markdown, and a body is worth writing when the title alone won't be enough
to act on later — the repro, the file and line, the command that failed. One rule: **a note heading
is `## ` plus a checkbox and nothing else is**, so a `##` section inside a body is just content and
will not split the note.

When to write one, and when not:

- **Do** when I ask you to note something down, or when you find something real that is genuinely
  outside the scope of what I asked you to do and would otherwise be lost.
- **Don't** narrate your own progress into it, and don't file what belongs in the work I am already
  reviewing — a finding about the code you are currently writing goes in your reply to me, not here.
  A scratchpad I have to prune is worse than no scratchpad.

### Decision points

The panel doubles as my queue of *things waiting on me*. So: **when you have to guess at something
only I can settle, proceed under your best assumption and leave a note saying what you assumed.**

The test is whether I could still change my mind later and whether it would cost something if I
never found out. A timeout value you invented, a spec that contradicted itself and you picked a
reading, a fix you deliberately scoped out — those are mine to settle and I will not remember them
unless they are written down.

**Ask me directly instead whenever I am here and responsive.** A note is for a decision you made
*in my absence* — mid-way through a long autonomous run, or where stopping to ask would have blocked
everything else. If we are talking, the reply is the right place and a note is a second copy I have
to close.

One note per decision, titled so it is actionable without opening it, and **prefixed with the
project** — the scratchpad is global, so `blueberry: kept the v3 modal` tells me where to look and a
bare `kept the v3 modal` does not:

```sh
agent-mgr note add "blueberry: kept the v3 modal, the v4 spec is ambiguous" --body - <<'EOF'
Two conflicting layouts in the v4 source, with nothing saying which supersedes.
Went with v3 because it is what ships today.

Reversing it is `git revert abc1234` — nothing else depends on it.
EOF
```

Put the alternative and the cost of switching in the body. A decision I can reverse in one command
is a different thing from one I cannot, and the title has no room to say which.
