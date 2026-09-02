---
name: todoist
description: File tasks into Pete's Todoist that only Pete can do (set up API keys, approve access, buy/decide/sign things), bound to the current repo's own Todoist sub-project (parent chosen by Pete), and later check whether he completed them. Use when work is blocked or deferred on a human-only action — "ask Pete to…", "add a todo for me", "add items to my todoist that I need to do for this project", "did I finish the asks for this repo".
argument-hint: 'file "<imperative title>" [--blocking] [--due YYYY-MM-DD] | check | list'
---

# File and track human-only asks in Todoist

A task belongs here only when the agent **literally cannot do it** — a credential to provision, an
account to approve, a purchase, a decision that is Pete's alone. Anything an agent could do itself
is not an ask; do it or put it in the work you're already delivering. Todoist is the source of
truth for status; the local JSON file is only an append-only index of *what this repo has asked*,
so a later session knows which task IDs to look up.

Structure in Todoist: one sub-project per repo, named exactly after the repo directory. The
**parent** varies — `Personal Projects` for personal repos, a client/org parent like `kreinto`
for work — so the repo *name* is the binding, never a fixed parent. Every agent-filed task
carries the `agent` label; that one label gives Pete a single cross-repo filter of everything
agents are waiting on him for.

## 1. Preflight

```bash
# Agent shells are usually non-interactive and never source .zshrc → .zshrc.local, so pull the
# token in explicitly before deciding it's missing.
[ -n "$TODOIST_API_TOKEN" ] || [ ! -f ~/.zshrc.local ] || source ~/.zshrc.local
# Still unset (a cloud session, a fresh machine)? The 1Password service account can read it:
# the token lives in the 'Kreinto Infra' vault so any session anywhere can file an ask.
[ -n "$TODOIST_API_TOKEN" ] || ! command -v op >/dev/null || TODOIST_API_TOKEN=$(op read "op://Kreinto Infra/todoist-api-token/credential" 2>/dev/null || true)
: "${TODOIST_API_TOKEN:?TODOIST_API_TOKEN unset — get a token from Todoist → Settings → Integrations → Developer; put it in 1Password as 'todoist-api-token' in 'Kreinto Infra' (op read fallback above) and/or 'export TODOIST_API_TOKEN=<token>' in ~/.zshrc.local (never anywhere that gets committed)}"
command -v jq >/dev/null || { echo "jq required — brew install jq / apt-get install jq"; exit 1; }

repo="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
state_dir="${AGENT_WORK_DIR:-$HOME/agents}/todoist"
state_file="$state_dir/$repo.json"
mkdir -p "$state_dir"; [ -f "$state_file" ] || echo '[]' > "$state_file"

api=https://api.todoist.com/api/v1
auth="Authorization: Bearer $TODOIST_API_TOKEN"
```

Use `curl -sf` on every mutating call so an HTTP error aborts instead of parsing an error body as
data. On failure, retry once; if it still fails, **surface the ask verbatim in your reply to the
user** — a dropped ask is the one failure mode this skill exists to prevent.

## 2. Resolve the project

Look for a project named exactly `<repo>` **anywhere** in Pete's tree — don't assume a parent:

```bash
projects=$(curl -sf "$api/projects?limit=200" -H "$auth")
# Paginated: {"results": [...], "next_cursor": ...}. Follow &cursor=<next_cursor> until null
# (irrelevant below 200 projects, so usually one call).

proj_id=$(jq -r --arg r "$repo" '.results[] | select(.name==$r) | .id' <<<"$projects")
```

One match → use it. When it's **missing**, creating it is a placement decision in Pete's curated
project tree — different repos belong under different parents — and who decides depends on
whether Pete is there to ask:

- **Pete is present** (interactive session) → ask before creating. List his top-level projects
  (already in `$projects`) and ask which should be the parent, or top-level: "No `<repo>` project
  in Todoist — where should it go?" Create with the chosen project's id as `parent_id` (omit it
  for top-level).
- **Running unattended** → don't block the run. Guess from the repo's path: a repo under a
  client/org directory (e.g. `~/GitHub/kreinto/…`) goes under a top-level project matching that
  name if one exists; otherwise use `Personal Projects`. Then flag the guess per the
  decision-points rule in `AGENTS.md` — a scratchpad note
  (`agent-mgr note add "<repo>: created Todoist project under <parent>"`) plus a line in your
  summary. Moving a project is drag-and-drop in the app, so a wrong guess costs Pete seconds —
  the note, not the placement, is the important part.

```bash
proj_id=$(curl -sf -X POST "$api/projects" -H "$auth" -H 'Content-Type: application/json' \
  -d "$(jq -n --arg n "$repo" --arg p "$parent_id" '{name:$n, parent_id:$p}')" | jq -r .id)
```

If **several** projects share the repo's name, ask Pete which one; unattended, prefer the one
whose parent matches the path heuristic and say so in the note.

## 3. File a task

Shape of a good ask:

- **Title** — the imperative action, specific enough to act on from a phone
  (`Set up STRIPE_API_KEY in ~/.zshrc.local`, not `API keys`).
- **Description** — what the title has no room for: *why* it's needed, *how to verify* it's done,
  and the filed date + repo so the task is self-explanatory weeks later in the app.
- **Priority** — the API and UI number priorities in opposite directions: API `4` = UI **p1**.
  Default to API `2` (UI p3); use API `4` only when the current work is genuinely blocked on it.
- **Due date** — only when something is truly time-bound (`due_date: "YYYY-MM-DD"`). An invented
  due date is noise that trains Pete to ignore the real ones.
- **Label** — always `agent`. Label names in the `labels` array auto-create on first use.

```bash
task=$(curl -sf -X POST "$api/tasks" -H "$auth" -H 'Content-Type: application/json' -d "$(jq -n \
  --arg c "Set up STRIPE_API_KEY in ~/.zshrc.local" \
  --arg d "Why: payments integration is blocked without it.
Verify: echo \$STRIPE_API_KEY prints in a new shell.
Filed: $(date +%F) by agent from $repo" \
  --arg p "$proj_id" \
  '{content:$c, description:$d, project_id:$p, labels:["agent"], priority:2}')")
task_id=$(jq -r .id <<<"$task")
```

Record it in the index **only after** creation succeeded, atomically (temp file + `mv` — another
session may be filing at the same time). If the state write fails, print the task ID loudly so the
task isn't orphaned in Todoist with no index entry.

```bash
tmp=$(mktemp "$state_dir/.tmp.XXXXXX")
jq --arg id "$task_id" --arg t "$(jq -r .content <<<"$task")" --arg f "$(date +%F)" \
  '. + [{id:$id, title:$t, filed:$f}]' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
```

## 4. Check asks / list open

Query each recorded ID live — never infer status from the file. Completed tasks still return
`200` with `checked: true` (verified live; `completed_at` says when), so a `404` means the task
was **deleted without being completed** — report it as deleted, never as done.

```bash
jq -r '.[].id' "$state_file" | while read -r id; do
  body=$(mktemp "$state_dir/.chk.XXXXXX")
  code=$(curl -s -o "$body" -w '%{http_code}' "$api/tasks/$id" -H "$auth")
  case "$code" in
    200) [ "$(jq -r .checked "$body")" = "true" ] && echo "$id done" || echo "$id open" ;;
    404) echo "$id deleted" ;;
    *)   echo "$id error:$code" ;;
  esac
  rm -f "$body"
done
```

Report the result as a table — title, filed date, open/done/deleted — and lead with what's still
open, since "what is Pete still on the hook for" is the question being asked. `list` is this same
flow filtered to open items. The check never mutates the state file: re-querying is cheap, and
the file stays a pure record of what was asked.

## 5. Failure modes

- **Token unset** — the preflight `:?` fails with setup instructions; don't work around it.
- **jq missing** — install it (it's in both package lists); don't reimplement the JSON handling.
- **Network / non-2xx** — retry once, then put the ask in your reply instead. **Never report a
  task as filed, or guess at completion status, when the API didn't confirm it.**

## Arguments

- `/todoist file "<title>" [--blocking] [--due YYYY-MM-DD]` — file one ask (`--blocking` → API priority 4).
- `/todoist check` — status of every ask this repo has filed.
- `/todoist list` — only the still-open asks.
