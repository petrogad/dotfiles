---
name: claude-design-implement
description: Implement a Claude Design prototype (a claude.ai/design project, files ending .dc.html) in a real codebase, wiring every displayed number to real data. Use when given a link like https://claude.ai/design/p/<projectId>?file=<File>.dc.html, or asked to "build this design", "implement the mockup from Claude Design", "make the app match the design project". Covers fetching the files, reading the prototype, the data audit, the scope questions to settle up front, and page-by-page delivery. Not for creating or editing the design itself.
---

# Implement a Claude Design project

A design prototype is mock data in a nice layout. The work is mapping each thing it shows to a
real source, settling what cannot be real with the human before building, and shipping one page
at a time so they can look between pages.

## 1. Fetch the files (once), keep local copies

From the URL take `projectId` (the segment after `/design/p/`) and `file` (URL-decoded, e.g.
`My App Admin.dc.html`).

1. Load the tool: `ToolSearch` with `select:DesignSync`. Read its schema; the calls used are
   `method: "list_files"` with `projectId`, and `method: "get_file"` with `projectId` and `path`.
   If it does not load, tell the human: do not reconstruct the design from screenshots or memory.
2. `list_files`, then `get_file` the main `.dc.html` and every local script it loads
   (`<script src="./support.js">` and similar; ignore `uploads/`, `.thumbnail`, `screenshots/`
   unless asked). A `README.md` in a `design_handoff_*` folder is worth reading too.
3. Results over the inline limit are saved to a tool-results file as JSON
   (`{"method","path","content"}`). Extract each into the session scratchpad, never the repo:

```sh
D="$SCRATCHPAD/design"; mkdir -p "$D"
jq -r .content <tool-results-file> > "$D/<File>.dc.html"
```

From then on read the local copies with `grep`/`sed -n` ranges. Do not call `get_file` again:
the main file is often 100 KB or more.

## 2. Read the prototype

- `<x-dc>` holds the template (markup plus a `<style>` block in `<helmet>`).
- `<script type="text/x-dc" data-dc-script data-props=...>` holds the logic and the **mock data**;
  `data-props` lists the tweakable props (a price, a toggle). `support.js` is the generic runtime:
  skim it only if behaviour is unclear.
- List the pages or tabs, and per page its sections in order. For each section note every number,
  label, chart and control, and where the prototype gets its value (constant, generated series,
  derived from other mock values).

## 3. Data audit (before any UI code)

Build a table per page: displayed item, real source (endpoint and field, or table and column),
status. Search the codebase for existing endpoints, DTO schemas and repository queries first.
Use the codebase-memory graph when the repo is indexed (`list_projects`; for a bare-repo layout the
`main` worktree's index serves every branch at the same commit) and name that project in any
audit agent's brief; fall back to grep for literals and docs.

| Status | Meaning |
| ------ | ------- |
| available | an existing endpoint already returns it |
| small API addition | stored data supports it; needs a field or query added |
| impossible | the database does not store what it needs (no timestamp, no event, no column) |

Also note per-item time semantics: does a range selector apply, is it all-time, is it a snapshot.
A label must say what the number actually is.

Hand the code search to one read-only agent (Explore) with the prototype's item list, and keep its
table, not its reading. Every file your own session reads stays in its context and is re-read on
every later turn.

## 4. Settle scope with the human up front

Use `AskUserQuestion` (batch the questions, recommend one option each, say why). Typical ones:

- each **impossible** item: drop it, replace with the nearest honest metric, or start recording
  the data now (separate PR) and show it later;
- whether **small API additions** land in the same PR as the page or before it;
- controls that change the contract (range selectors, filters, pagination);
- existing panels or pages the design drops: remove, keep, or move.

Record the answers in a plan or handoff under `~/agents` (load `agent-docs`), not only in a
scratch brief: they carry to the next page and survive a lost session. Do not start building until
these are settled.

If a repo rule seems to forbid part of the design (a fingerprinted stylesheet, a parity check),
quote the rule and ask, or find where the rule does not apply. Do not silently drop the part.

## 5. Decide who builds, then build

Make the call right after scope is settled, and write it in the handoff with the estimate. Size
it by the new code to write (contract, service, route, page and their tests), not by files touched:
one-line caller moves, generated files (migration snapshots, lockfiles) and doc lines do not count.

- **Small** (under about 1,000 new lines, one pattern already in the repo to follow): build in this
  session. Workers would each pay the entry fee to read the same files. Measured: a page touching
  24 files but with about 700 new lines cost the least per file of seven pages when built in-session.
- **Larger** (well over 1,000 new lines, or separate API and page work that each need their own
  reading): build through workers, below.
- **Either way**, past about 150k of your own context, feedback rounds, CI fixes and the
  PR/merge/deploy watching go to a fresh worker or a fresh session (`/pickup`), not to this one.
  Watching CI needs the PR number, not the build history.

### Building through workers; the main session briefs and reviews

Cost is roughly turns times context: every turn re-reads the whole conversation. Measured on three
pages where the main session built everything itself: 100 to 145 turns, context peaking near 300k,
about 20M tokens in the main session alone. The main session's job is scope,
briefs, review and the human; workers read templates and write code.

1. **Write the build brief** into the handoff under `~/agents` (load `token-economy` for the brief
   template): the settled decisions (do not relitigate), the data table from step 3, the endpoints
   and contract shape, which existing files to mirror, the tests to write, and the repo docs and
   skills for the area by path (`AGENTS.md`, `CLAUDE.md`, `docs/agents/`, `.claude/skills/`,
   `.agents/skills/`), the stack skill first.
2. **Spawn the workers**, strongest model unless `token-economy` says otherwise, split so no two
   touch the same file. Typical: one for contract + API + its tests, then one for the page + its
   tests once the contract exists. Shared files (route tables, nav, registries) stay with you.
3. **Review the diff, not the files.** `git diff --stat`, then the hunks that matter. Do not open
   the templates the workers copied. Re-run the gates they claim (typecheck, the touched tests).
4. **Human feedback goes to a worker.** After the human's look, brief a fresh worker with the
   requested changes and the files they touch. Edit directly only for a copy or style tweak of a
   few lines.
5. **Watch your own context.** Past about 150k, commit, update the handoff and continue in a fresh
   session (`/pickup`) rather than spawning more from a large context.

Rules every brief carries:

- Reuse the repo's tokens, components and chart primitives. Translate the prototype's inline
  styles and hex colours to existing tokens; add a token only when nothing fits, and say so.
- Respect the repo's theme rules (light and dark, contrast, reduced motion) even where the
  prototype only shows one theme.
- Follow the repo's data-loading, error and empty-state patterns rather than the prototype's
  mock-data shapes. Never ship mock values; an item without a real source is not rendered.
- Add or update the API contract, server and tests together when a page needs a new field.
- Tests while iterating: only the files touched, plus a quick typecheck of that package.

## 6. Verify and hand over, then wait

1. Run the app, open the page in a browser (both themes, a narrow width), compare it against the
   prototype section by section, and check the network calls return real data. Before trusting
   what you see, confirm the dev server serves the current source (fetch a changed module and
   grep it for a new string): a containerised dev server can miss host edits and serve a stale
   module graph, which shows up as a blank page.
   If a worker did the browser check, re-check the headline claims yourself before reporting them.
2. Give the human a URL they can open from their own machine (the host's LAN address, checked
   with curl from that address first), not `localhost`.
3. Report: what was built, a list of **deviations from the design with the reason for each**
   (impossible data, reused component, theme rule), and which tests were skipped.
4. Wait for the human's look before starting the next page. Run the full suite once, when they
   say it is ready to commit.
5. Add a short **Lessons** list to the plan: each item tagged `repo` (agent docs or a repo skill),
   `global` (a global skill or AGENTS.md) or `memory`, so gaps become documentation.
