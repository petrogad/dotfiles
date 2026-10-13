# Agent instructions

Agent-agnostic standing instructions — the single source of truth for every agent, and the only
place these belong. `make agents` builds `~/.agents/AGENTS.md` from this file plus, when present,
the private overlay in `dotfiles-private/agents/AGENTS.md` (machine names, addresses, accounts —
anything that should not be public). Codex reads `~/.agents/AGENTS.md` natively; Claude Code reads
`~/.claude/CLAUDE.md`, a symlink to it, so both see the same words. Add standing instructions here
(or in the overlay if they are private), not in either agent's own config or the built file, and
re-run `make agents`. Grow this over time.

## References

If I ask you to read a reference or file, URL, issue, ticket, or ANY document and you are not able to retrieve it, TELL ME so we can fix the issue. Do not just ignore or work without the reference material.

## Links I can open

I am often on a different computer from the one you are running on. Any URL you give me for
something running on your machine (a dev server, a stack, Mailpit, a preview) uses the machine's
LAN address, never `localhost` or `127.0.0.1`: e.g. `http://192.168.1.50:4562`, not
`http://localhost:4562`. Look the address up (`ipconfig getifaddr en0` on a Mac,
`hostname -I` on Linux) and check the URL answers from that address before handing it over. If
the service is bound to loopback only, say so instead of giving me a link that cannot work.

## Tests while iterating

While we are iterating on something together (I look, I ask for a change, you change it, I look
again), do **not** run the full test suite, lint or typecheck across the repo after each round.
Make the change, rebuild or restart whatever I am looking at, and hand it back fast. A typecheck
of what you touched is fine when it is quick.

Run the full suite once, when I say we are ready to commit or push, and fix whatever it finds then.
Say in your reply which tests you skipped, so I know they are still to run.

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
