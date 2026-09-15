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

## The home fleet

Two HP EliteDesk boxes running Proxmox, plus Macs for anything Apple. A map, not
a manual — the detail lives in `kreinto-infra` and in `~/agents/plans/`.

| Host | Address | Is |
|---|---|---|
| `labs` | `192.168.1.3` | Proxmox. Staging + apps. |
| `labs-pg` | `192.168.1.10` | PostgreSQL 18. Staging databases and clone templates. |
| `labs-apps` | `192.168.1.11` | Docker. Serves `*.lab.kreinto.io`. Holds the deploy runner. |
| `forge` | `192.168.1.4` | Proxmox. Dev. |
| `forge-dev` | `192.168.1.21` | **The dev node. `ssh dev`.** Where work happens. |

Names resolve as `<host>.home.arpa` from the UDM. `home.arpa` and not a
`kreinto.io` name because kreinto.io sends HSTS `includeSubDomains; preload`,
so browsers hard-reject self-signed certs on any subdomain — including Proxmox
on `:8006`.

**Work on `forge-dev`, not on a Mac.** The Macs exist for what Linux cannot do:
Xcode/iOS, real Safari/WebKit, hardware checks. Everything else — web, API,
Android, databases, agents — belongs on `forge-dev`.

### Databases: never run a local Postgres

`labs-pg` holds the canonical seeded content. Per project there are three:

    <project>           staging. The deployed labs app is connected to it.
    <project>_seed      clone template, owned by `dev`, nothing connected.
    <project>_<branch>  what you make and destroy.

    db-clone <project> <branch>    # ~0.1s, fully migrated
    db-drop  <project> <branch>
    db-ls                          # only your clones

`createdb -T` refuses a template with open connections, which is why the seed
exists separately from staging; and it is server-local, which is why clones live
on `labs-pg` rather than beside you. `refresh-seed <project>` on `labs-pg`
re-snapshots staging into the seed — run it after a merge that changes schema.

A project's dev compose that still ships its own `postgres` service should be
pointed at a clone instead.

### Worktrees

`_worktree <branch>` from the repo root, then `scripts/setup-worktree.sh`, which
derives a port block from the branch so parallel worktrees never collide. Reach
a branch's stack at `192.168.1.21:<port>` — check the generated `.env` for which.

### Android on real hardware

Builds and installs to a physical device from `forge-dev`. No emulator, and no
Mac involved.

    flugo-android [port]     # ~/.local/bin — sets up the tunnel, builds, installs

Two things that will otherwise waste an hour:

- **`adb reverse` is mandatory, not a convenience.** `ApiEnvironment.kt` and the
  debug `network_security_config.xml` both permit cleartext only to `localhost`,
  `127.0.0.1`, `10.0.2.2`. Point the app at a LAN IP and it throws
  `API origin requires HTTPS` and dies at launch. `adb reverse tcp:PORT tcp:PORT`
  makes the phone's own localhost reach the dev node, so the guard stays intact.
- **The tunnel dies with the adb connection.** Wifi drop, re-pair, toggling
  wireless debugging — all silently break it, and it presents as the API being
  down. Re-run the helper.

Demo sign-in for seeded stacks: `jordan@northgateultimate.org` /
`demo-password-1`. Staging on `labs` has **no** demo users — `SEED_DEMO=false` is
refused under `NODE_ENV=production`.

### Deploys

Merge to the default branch deploys to `labs-apps`; there is no staging branch.
A self-hosted runner on that host builds and `docker compose up`s locally.
App repos carry `docker-compose.baseline.yml`, `.env.baseline.example` and a
`deploy.yml`. (They were called `*.mini.*` when the baseline host was a Mac mini.)

`cusp` is the exception: it lives in the `Cusp-Media-LLC` org, and cross-org
private repos can neither call `kreinto-infra`'s reusable workflow nor use its
runner — so it carries its own copy of both.
