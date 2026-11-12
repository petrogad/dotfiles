---
name: token-economy
description: How to spend tokens well when delegating work to subagents or choosing models. Read BEFORE spawning more than one subagent, fanning out parallel workers, picking a model tier for a worker or a reviewer, or when the user mentions token usage, cost, "token mindful", or that agents feel excessive. Also read when an orchestrating session's own context has grown large.
---

# Token economy for delegated work

"Token mindful" means **no wasted work**. It does not mean "the cheapest model". Measured on a real
build (one PR, about 60 files): 23 agents cost about 5M tokens, and a leaner structure would have
been about half, with the same result. The waste was structural, not the reviews.

## Pick the model by what a mistake costs

| Work | Model tier |
|---|---|
| The hardest items: integration, migrations, writes, edits to shipped code, SQL correctness and cost, accuracy tests, anything with nothing reviewing behind it | strongest available |
| **Every review**, including reviews of strong-model output | strongest available. A review by a model weaker than the author is not a review. |
| Substantial authoring that carries some risk | one tier below the strongest |
| Presentational or mechanical work on already-reviewed foundations | mid tier |
| Unit tests for one small, pure module (parsers, formatters, aggregate helpers) | mid tier, briefed with **only** the file under test, the spec it must satisfy, and the test conventions to copy |
| Read-only scouting and search | small is fine, but treat what it reports as a claim to verify, not a fact |

Do not author with a small model and plan to fix it in review. Measured: five small-model units all
self-reported "clean"; together they held 22 blockers (endpoints that threw on every call, a page
that could not render, wrong percentages), and the code was then written three times: small author,
mid repair, strong repair. One strong author plus one strong reviewer is cheaper AND safer.

**Delegated unit tests need the spec, not just the file.** A model shown only the implementation
writes tests that confirm its bugs. So the brief includes the rule text or glossary the code must
meet, the author runs and reads the tests before accepting them, and the strong reviewer still
checks them for tests that can never fail. Keep these on the strongest model: golden/replay
tests, reality checks against real data, compatibility tests, and anything touching a database,
API or job queue.

## Structure the fan-out

1. **Say the bill first.** Before fanning out, tell the user the agent count, the tiers and a rough
   token estimate, and let them trim it. Default to the fewest agents that can work in parallel
   without touching the same files.
2. **Every agent pays an entry fee** before it does anything: system prompt, tools and the project's
   instruction files. Measured at about 70k per agent with a 28k-token project instruction file. So:
   fewer, larger units. One reviewer should cover all related files so shared reading is paid once.
3. **Give workers a short, dedicated brief file**, not the narrative plan. A plan that grows all day
   is re-read in full by every agent that is pointed at it.
4. **Own the shared files yourself.** List every file more than one unit needs (registries, closed
   union types, route tables, barrel exports) before fanning out, and keep them with the
   orchestrator. A unit that cannot compile without a shared edit will either break ownership or
   cast around the type.
5. **Workers verify with a typecheck, not just lint and their own tests.** Lint passing was read as
   "types are fine" by every small-model worker.

## The worker brief

A brief is a file, self-contained, and short. Every brief names:

- **Where:** the worktree path and branch; "work only here"; never `git stash` (the stack is shared
  across worktrees); push / PR / merge permissions stated explicitly.
- **Decisions already made** by the human, marked "do not relitigate", and the orchestrator's own
  assumptions, marked as reversible so the worker flags them.
- **Context to load:** the repo's agent docs and skills for this area, by path, and the
  codebase-memory project name if the repo is indexed ("graph first for code lookups, grep for
  literals and docs").
- **Gates:** which tests to run now and which to leave; how to verify in a browser or on a device.
- **Done when:** the checks that prove the unit is finished, written so the worker can run each
  one itself: the tests that must pass, the screen or endpoint to check and what it must show,
  and the bar the reviewer will hold it to. A worker that knows the reviewer's bar meets it in
  round one.
- **Report shape:** what was built, deviations with reasons, tests run and skipped, assumptions,
  and one line on which of the listed context it actually used. That line is how briefs improve.

### Keep workers lean

A worker re-reads its whole context on every turn, so what it reads and how many turns it takes
decide its cost. Measured on one page built by two workers: 15M tokens between them, against 7M for
the orchestrator that briefed and reviewed them.

- **Name exact lines, not templates.** "Copy `Board.tsx` lines 40-120 for the table; the design is
  lines 493-545 of the local copy" instead of "mirror the Teams board". A worker told to mirror a
  page reads all of it, plus its neighbours.
- **One owner for the browser check.** Say who takes screenshots: usually the orchestrator, once,
  after both workers report. A worker that also checks the page carries every screenshot for the
  rest of its run.
- **Fewer, larger steps.** Write the file, typecheck and run its test in one command; read two
  related files in one call. Each turn costs the whole context again.
- **Quiet gates.** Ask for failures only (`--reporter=dot`, `| tail -30`), never full passing output.
- **Model by what it builds.** Presentational work on a contract that is already written and
  reviewed can go to the mid tier (see the table above); run it after the API worker instead of in
  parallel when that saves a strong-model run.

Start a fresh agent per round with a new brief. Do not resume a long-running worker round after
round: its whole transcript is re-read on every turn.

**Fix rounds go to the mid tier when the review already did the thinking.** If every finding
names the file and the change to make ("rename X in `a.ts`", "add the missing null check at line
40", "drop the unused export"), the round is mechanical: brief only those findings and the files
they name, and use the mid tier. A finding that asks for judgment, such as a redesign, a
correctness question, SQL or anything on the strongest-tier list above, keeps the strongest
model. The re-review is still a review, so it always gets the strongest model.

## Run the orchestration cheaply

- Batch completion notifications. Reply to the user when there is a decision or a result, briefly.
  A long status message from a large context, forty times, is a real cost.
- Verify a subagent's claim before repeating it to the user, or label it unverified. Re-run "tests
  pass"; do not quote it.
- **The orchestrator does not build.** For any change over about five files, the main session
  settles scope, writes the brief, spawns workers, reviews their diffs and talks to the user. It
  does not read the templates or write the code: whatever it reads stays in its context and is
  re-read every turn. Measured on three single-session pages: 100 to 145 main-session turns
  at 150k to 190k average context, about 20M tokens each, 97% of it re-reading the conversation.
- When the orchestrator's own context passes roughly 150k tokens, stop spawning from it. Commit,
  write a handoff, and continue in a fresh session (`/handoff`, then `/pickup`). A fresh session
  starts near 60k; every tool call from a 300k context re-reads 300k. This holds for a single
  session too: once the PR is open and context is past 150k, the CI, merge and deploy watching
  moves to a fresh session or a small worker given the PR number.
- A bloated or stale project instruction file is a standing tax on every session and agent. Propose
  trimming it to an index that points at topic files, moving text verbatim rather than rewriting it.

## What is NOT waste

Review layers that keep finding real defects. On the same build each layer (mechanical checks, a mid
reviewer, a strong reviewer) caught blockers the layer before had passed, including an accuracy bug
that survived two reviews and a security test that could not fail. Cut structure, not review. The
cheap mechanical layer is worth running on every unit: file ownership via `git status`, banned
patterns, re-running the unit's own tests, a typecheck.
