# Agent instructions

Agent-agnostic standing instructions — the single source of truth for every agent, and the only
place these belong. `make agents` builds `~/.agents/AGENTS.md` from this file plus, when present,
the private overlay in `dotfiles-private/agents/AGENTS.md` (machine names, addresses, accounts —
anything that should not be public). Codex reads a copy at `~/.codex/AGENTS.md` (installer blocks
such as codebase-memory's carried over); Claude Code reads `~/.claude/CLAUDE.md`, a symlink to it, so
both see the same words. Add standing instructions here
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

## Name the tmux window

My tmux windows start out named `zsh`. Once you understand what we are working on (usually after
my first real request, not on a greeting), name the window by running
`agent-title "Short Name"`: Title Case, letters, digits and spaces, 20 characters at most, naming
the work rather than the repo (`Axiom Setup`, `Tmux Auto Names`). Run it again only when the work
has clearly moved to a different topic, never for a sub-step of the same one. The script keeps
any name I set by hand and refuses renames within 20 minutes of the last, so a "left alone" or
"cooldown" reply is expected: carry on and do not retry. It is a no-op outside tmux.

## Tests while iterating

I verify by hand first: on the iOS device or simulator, the Android phone, or the browser. Until I
have looked and said it works, we are iterating (I look, I ask for a change, you change it, I look
again), and that is the default for any change I will see on a screen. While iterating, do **not**
run the full test suite, lint or typecheck across the repo, and do not stop to write tests. Make
the change, rebuild, reinstall or restart whatever I am looking at (`build-android`, the simulator
build, the dev server), and hand it back fast. A typecheck of what you touched is fine when it is
quick.

Tests come after my verification. When I say it works, or that we are ready to commit or push,
write the tests the change needs (see "Writing code"), run the full suite once, and fix whatever it
finds then. Say in your reply which tests you skipped or have not written yet, so I know they are
still to do.

## Writing code

- **Map the change before you make it.** List every place it must reach: callers, tests,
  fixtures, config, exports. Then check what it could break: data it would destroy or expose,
  callers that stop working. That is the scope; features nobody asked for are not. Then finish
  all of it: the callers, tests and fixtures your change breaks are part of the change.
- **Keep the structure the codebase already has**: its layers, interfaces, naming and
  conventions. A smaller change never justifies routing around them.
- **Fix bugs at the root.** Before editing a function, grep every caller of it, then fix the
  cause once in the shared code instead of patching the one call site that showed the bug.
- **Reuse before you add.** A helper or pattern already in the codebase first, used the way the
  surrounding code uses it; then the standard library or platform; then a dependency already
  installed. Never add a dependency for a few lines.
- **Build only what is needed now.** No "for later" code, options or config. Write the obvious
  solution first; optimize only when a measurement shows it matters. Between options of equal
  size, take the one that is correct on edge cases.
- **Extract on the third copy.** Two similar blocks can stay; abstract when a third appears,
  and use the existing helper if there already is one.
- **Mark shortcuts where they live.** A known limit you chose to accept gets a one-line comment
  in this form, so it can be grepped later: `shortcut: <the limit>, <when to upgrade>`.
- **Never cut** validation at trust boundaries, error handling that prevents data loss, security,
  accessibility, or anything I asked for. Code you move or merge keeps its error handling and
  validation.
- **Fail loudly.** Explicit errors over silent fallbacks: no empty catches, no defaults that
  hide a bad value, no swallowed promise rejections. An error that reaches me beats one that
  turns into wrong data.
- **Delete what your change makes dead** (the old function, the flag, the unused import), after
  grepping that nothing else uses it. Do not delete code you merely suspect is unused; name it
  in the closing line instead.
- **New non-trivial logic leaves a test.** A branch, a loop, a parser, anything touching money or
  security, or a whole new script: one small test or an assert-based self-check. Trivial changes
  need none. It is written after I have verified the change by hand, not during iteration; see
  "Tests while iterating".
- **End the reply with what you skipped.** One or two lines: what you did not do or did not check,
  and any risk I need to know about.

## Work-management docs

Research, plans, handoffs, and reviews are work management, not code. They live under
`$AGENT_WORK_DIR` (`~/agents`) and are **never** written into a repo or committed. One-off scripts,
utilities, and diagrams go in `$AGENT_WORK_DIR/artifacts` rather than being left loose in a repo.

Before creating or updating any of these, load the **`agent-docs`** skill for the shared conventions
(dirs, metadata block, status vocab, filenames, archive lifecycle) — including when writing one
adhoc, without going through `research` / `plan` / `handoff` / `pickup`. If a project-specific doc
skill scopes the area you're working in, it wins.

## Orchestrating subagents

Before spawning more than one subagent, load **`token-economy`** (model tiers, the brief template,
"say the bill first") and **`agent-docs`** (decisions go into a plan or handoff, not a scratch file).
In Claude Code the `skill-gate` hook refuses a second spawn until both are loaded, and refuses a
worker brief in a repo with skills unless it names the relevant ones or says `Skills: none apply`.

- **Resolve the codebase graph once:** `list_projects`, and if the session starts in a repo's parent
  directory (the `.bare` layout), use the `main` worktree's index. Name the project in every brief.
- **Graph to locate, grep to confirm callers:** where something is defined goes to the graph
  (`search_graph`, `get_code_snippet`; the "graph symbol(s) match" hint beside a grep is the same
  index). `trace_path` misses calls made through an object (`deps.sessions.revoke(...)`,
  `services.x.y(...)`), which is how service-layered code calls, so "0 callers" is not an answer:
  grep the method name before saying what a change touches. Literals, config, docs and known files:
  grep and Read.
- **List the repo's own help** in every brief by path: its agent docs for the area and its skills
  (`.claude/skills`, `.agents/skills`). Most misses are knowledge that existed and was not read.
- **Write "Done when" into every brief:** the checks that prove the unit is finished (the tests
  that must pass, the browser or device check, the reviewer's bar). A worker without them comes
  back for round two and three. In one 34-agent end-to-end build, about a third of them were
  fix-and-re-review rounds.
- **Verify before relaying:** re-run a worker's "tests pass" or re-check its browser claim before
  repeating it to me, or label it unverified.
- **Close the loop:** end each orchestration with a Lessons list in its plan or handoff, each item
  tagged repo, global or memory, and propose the doc or skill change as a PR.
- **Measure it:** `session-measure watch [id|latest]` streams a running session's skill loads,
  agents, stack commands and context marks; `session-measure audit [id|latest]` reports turns, peak
  context, billed weight (main vs workers) and skills whose triggers fired but were not loaded. Put
  the audit in the work's plan or handoff and compare billed weight with earlier runs.

## Decision points

**When you have to guess at something only I can settle, proceed under your best assumption and say
what you assumed.** The test is whether I could still change my mind later and whether it would
cost something if I never found out — a timeout value you invented, a spec that contradicted itself
and you picked a reading, a fix you deliberately scoped out.

**Ask me directly whenever I am here and responsive.** Guess-and-flag is for decisions made *in my
absence*, mid-way through a long autonomous run. Flag each one in your final summary (and in the
handoff doc, if there is one), with the alternative and the cost of switching: a decision I can
reverse in one command is a different thing from one I cannot.

**Ask for everything up front.** Before starting a task, list in one message every key, token,
login, unlock and decision it will need from me, so I clear them in one sitting instead of one
round trip each. Anything that can wait goes into Todoist with the **`todoist`** skill. If a new
need turns up mid-task, batch it with any others before you stop.

## Merging and status

**Merge your own PR** without asking when all of these hold:

- CI is green.
- Review is clean, or the review round cap is reached with only non-blocking findings left, which
  are filed as follow-ups.
- It touches no money, billing, auth, secrets or data migrations, and nothing that deletes data.
- If it changes anything I will see on a screen, I have already looked and said it works.
- I have not said to hold it.

A production release or store submission is never covered by this rule; ask.

**Tell me, don't wait to be asked.** When a PR merges, a deploy lands, or you are blocked on me,
send a push notification where the agent supports one (Claude Code's `PushNotification`). Say
the outcome in one line, with the PR or URL. Do not leave me to ask "is it merged?" or "what's
next?". End each unit of work by naming the next step and whether it needs me.

## One topic per session

A session holds one topic, meaning one feature, fix or investigation and the PRs it needs. When
the work moves to a different topic, update the handoff (the **`handoff`** skill), tell me it is
written, and tell me to start a fresh session that runs **`pickup`**, rather than carrying the new
topic into a context that will compact. A compaction loses detail the handoff would have kept. If
the context is near its limit mid-topic, write the handoff before it compacts, not after.
