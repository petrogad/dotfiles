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

    cd <worktree> && build-android            # labs staging over HTTPS, no tunnel
    cd <worktree> && build-android --stack    # this worktree's own API_PORT, tunnelled
    cd <worktree> && build-android --origin <url>

Dev builds target our own infra, never production. The default origin is labs
staging (`https://<repo>.lab.kreinto.io`); `--stack` is the worktree's dev stack
through `adb reverse`; `--origin <url>` is anything else, tunnelled only when it
is a localhost URL. On flugo the debug app also ignores the production Clerk key,
so it shows the password sign-in: `testingk@k.invalid` / `password1`.

`build-android` takes no project name: it derives everything from where you are
standing. It finds the Gradle project by walking the worktree (flugo keeps it at
`apps/android`; a single-app repo has it at the root), and names the origin
property after the repo the remote points at — so `flugo.debugApiOrigin`, not the
worktree's name. Override the port with `--port N` (implies `--stack`) or the
property with `--prop NAME`; `--no-tunnel` builds without a phone. A repo
whose Gradle files never read the property is built plainly, with no port and no
tunnel required.

Two things that will otherwise waste an hour (both apply to localhost origins,
i.e. `--stack`):

- **`adb reverse` is mandatory, not a convenience.** `ApiEnvironment.kt` and the
  debug `network_security_config.xml` both permit cleartext only to `localhost`,
  `127.0.0.1`, `10.0.2.2`. Point the app at a LAN IP and it throws
  `API origin requires HTTPS` and dies at launch. `adb reverse tcp:PORT tcp:PORT`
  makes the phone's own localhost reach the dev node, so the guard stays intact.
- **The tunnel dies with the adb connection.** Wifi drop, re-pair, toggling
  wireless debugging — all silently break it, and it presents as the API being
  down. Re-run the helper.

Demo sign-in for seeded stacks: `jordan@northgateultimate.org` /
`demo-password-1`. Staging on `labs` has no demo users — `SEED_DEMO=false` is
refused under `NODE_ENV=production` — but it does have the dev accounts
`testingk@k.invalid` / `testingi@k.invalid`, password `password1`.

### Deploys

Merge to the default branch deploys to `labs-apps`; there is no staging branch.
A self-hosted runner on that host builds and `docker compose up`s locally.
App repos carry `docker-compose.baseline.yml`, `.env.baseline.example` and a
`deploy.yml`. (They were called `*.mini.*` when the baseline host was a Mac mini.)

`cusp` is the exception: it lives in the `Cusp-Media-LLC` org, and cross-org
private repos can neither call `kreinto-infra`'s reusable workflow nor use its
runner — so it carries its own copy of both.
