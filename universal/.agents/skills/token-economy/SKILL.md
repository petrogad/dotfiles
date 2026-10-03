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

## Run the orchestration cheaply

- Batch completion notifications. Reply to the user when there is a decision or a result, briefly.
  A long status message from a large context, forty times, is a real cost.
- Verify a subagent's claim before repeating it to the user, or label it unverified. Re-run "tests
  pass"; do not quote it.
- When the orchestrator's own context passes roughly 300k tokens, stop spawning from it. Commit,
  write a handoff, and continue in a fresh session (`/handoff`, then `/pickup`). A fresh session
  starts near 70k; every tool call from a 400k context re-reads 400k.
- A bloated or stale project instruction file is a standing tax on every session and agent. Propose
  trimming it to an index that points at topic files, moving text verbatim rather than rewriting it.

## What is NOT waste

Review layers that keep finding real defects. On the same build each layer (mechanical checks, a mid
reviewer, a strong reviewer) caught blockers the layer before had passed, including an accuracy bug
that survived two reviews and a security test that could not fail. Cut structure, not review. The
cheap mechanical layer is worth running on every unit: file ownership via `git status`, banned
patterns, re-running the unit's own tests, a typecheck.
