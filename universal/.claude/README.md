# Claude Code dotfiles

Stowed bits of `~/.claude/`: the hook scripts below and the status line. `make claude` (run by `make osx` / `make linux`)
registers them in `~/.claude/settings.json`. That file is never stowed because it holds
per-machine state such as `enabledPlugins`, so the target merges its entries in with
`extra/claude/merge-hooks.jq` and leaves every other hook alone. It is idempotent, keeps the
previous file as `settings.json.bak`, and skips a file that isn't valid JSON.

## `hooks/agent-mgr-hook`

Forwards Claude Code's hooks to [tmux-agent-mgr](https://github.com/petrogad/tmux-agent-mgr).
The plugin already shows each agent's state by watching processes. With the hooks it also gets
the agent's own report: why it is blocked, permission mode, subagents, task progress. `make
claude` registers this hook for every event in the plugin's `hooks/hooks.json`, so a plugin
update that adds an event only needs a re-run. If the plugin isn't installed, the hook exits 0
silently. Without the plugin at `make claude` time, only the banner is wired; run it again after
`make tpm`.

## `hooks/notify-banner.sh`

On `Stop` and `Notification`, shows a macOS banner ("Claude finished" / "Claude needs input")
with the Hero sound. It is suppressed when the pane Claude runs in is the active pane of a
window an attached tmux client is showing, i.e. when you are already looking at it. It does
nothing on Linux, so an agent on a remote box won't banner the Mac.

## `hooks/agent-title-hook`

On `SessionStart`, supports `agent-title` (`~/.local/bin`), which names the tmux window after the
work. A fresh session (startup or `/clear`) in the pane that owns the window's name, or in a window
nobody owns, gets the 20-minute rename cooldown cleared, since that cooldown belonged to the last
session's topic; resume and compact keep it. While the window still has its default shell name,
the hook reminds the agent to name it, and says nothing once it has one. A no-op outside tmux.

## `hooks/skill-gate`

On `PreToolUse` for the `Agent` tool, enforces two things the agent instructions already ask for and
the 2026-11-11 session audit found skipped. A second subagent spawn is refused until the session has
loaded `token-economy` and `agent-docs` (by the Skill tool, a slash command or a Read of the
`SKILL.md`). In a repo with its own skills (`.agents/skills`, `.claude/skills`, or the primary
worktree's when the session sits at a `clone-for-wt` root), a worker brief that names none of
them, and doesn't say `Skills: none apply`, is refused with the list of the repo's skills. Forks and
read-only lookup agents (Explore, web-fetch, the codebase-memory agents) skip the brief check. A
refusal is a deny with a reason, so the agent fixes it and re-issues the call; a hook error is
reported and the call goes through. Self-check: `bash tests/skill-gate.sh`.

## `hooks/cbm-index-check`

On `SessionStart` and `SubagentStart`, works out which codebase-memory index serves the repo. Every
repo here uses the `clone-for-wt` layout (`<repo>/.bare` plus a worktree per branch), and
codebase-memory only matches an index by exact directory, so a session started in `<repo>` or a new
worktree is told "no indexed graph project matched" and falls back to grep. This hook walks up to
`.bare`, picks the worktree's own index or the primary branch's (`master` before `main`, as
`_worktree` does), and tells the agent which project to pass. When the repo has no index, or its
index is 10 or more commits behind `origin/<primary>`, it also shows you a warning with the
`cbm-reindex` command that fixes it. It reads the index databases directly and finishes in well
under a second; on any error it prints nothing.

## `hooks/cbm-hook-augment`

Wraps codebase-memory's own `hook-augment`, which adds graph context beside each grep, Glob, Grep
and Read ("`activeSessionFilter` is a Function in `read.ts`") and at session and subagent start.
`make claude` points codebase-memory's hook entries at this wrapper. The binary goes silent in a
branch worktree for two reasons, and the wrapper fixes both before calling it:

- it matches the payload's `cwd` to an index by exact directory, so the wrapper moves a cwd inside
  an unindexed worktree (or `<repo>` itself) to the same place in the indexed primary;
- for Bash it only reads a command that starts with `grep`/`rg`, so the wrapper passes the first
  grep/rg segment of `cd <worktree> && grep ...`, with the `cd` applied to cwd.

When it moved anything it adds a line saying the graph's paths are the primary's, so agents edit
their own worktree. Replaying the 71 searches of one real session: 0 hints before, 39 after. It adds no time: the binary takes about 1.35 s per search either way.

### Keeping the index fresh

codebase-memory's watcher only re-indexes a checkout whose files change, and nothing used to change
the primary worktree: `_worktree` branches from `origin/<primary>` without touching it. So:

- `~/.config/worktree/hooks.d/post-create.d/50-primary-ff`: every `_worktree` fast-forwards the
  primary to the origin it just fetched (skipped, with a note, when it has tracked changes or has
  diverged) and re-indexes it when it moved, or when it has no index yet.
- `~/.config/worktree/git-hooks/post-merge`, linked into each `<repo>/.bare/hooks` by
  `install-git-hooks`: a `git pull` (merge or rebase) on the primary re-indexes it. It does nothing
  in other worktrees. Repos that set `core.hooksPath` (husky, `.githooks`) never run it; the
  installer says so and `cbm-index-check` covers them.
- `cbm-reindex [--if-missing] [--wait] <dir>` does the work: detached, one run per directory (a
  `mkdir` lock, since macOS has no `flock`), with git's hook environment cleared. Log:
  `~/.cache/codebase-memory-mcp/logs/reindex.log`.

`clone-for-wt` installs the hook and builds the first index. For repos cloned before this, run
`install-git-hooks` once (it finds every `.bare` under `~/dev` and `~/github`).

## Keeping secrets out of git and transcripts

Three guards, each for a different way a secret leaks.

- **`~/.config/worktree/git-hooks/pre-commit`** runs gitleaks on the staged changes and blocks a
  commit that contains a secret, with the finding redacted. `install-git-hooks` links it into each
  `<repo>/.bare/hooks` beside `post-merge`, so it covers every worktree, and `clone-for-wt` does
  that for new clones. It uses the repo's `.gitleaks.toml` when there is one. For a false
  positive, add the printed fingerprint to `.gitleaksignore`, or commit with `--no-verify` once
  you have checked it. If gitleaks isn't installed it blocks the commit and says so (it is in the
  Brewfile and `packages.txt`). Repos with their own `pre-commit` or a `core.hooksPath` are
  skipped with a message, so the CI scan is the backstop there.
- **`hooks/secret-guard`** (Claude Code, `PreToolUse` on Bash) refuses commands that print
  decrypted secrets into the transcript: `sudsy cat/json/get`, `op read/inject`,
  `op item get --reveal`, `sops -d/--decrypt/decrypt`, `age -d`. Running a program with secrets
  (`sudsy run`, `op run`, `sops exec-env`) stays allowed. It denies rather than asks, because the
  docs don't promise that an "ask" still prompts in bypass-permissions mode. It matches command
  text, so a wrapper script or alias gets past it.
- **`~/.codex/rules/secrets.rules`** (stowed from `universal/.codex/rules`) is the same list as
  Codex `forbidden` prefix rules.

## `session-measure`

`~/.local/bin/session-measure` (scripts in `~/.local/lib/session-measure/`) reads Claude Code
transcripts under `~/.claude/projects` for any repo:

    session-measure watch [SESSION|latest] [--dir DIR]   live events while a session runs
    session-measure audit [SESSION|latest] [--dir DIR]   after-action report (markdown)

`latest` is the session most recently started from DIR (default: the current directory), so running
it from another session in the same directory does not measure itself. Billed weight counts cache
reads at 0.1x, cache writes at 1.25x and output at 5x input. A repo's stack skill is whatever
`*-local-stack` skill it has; skill triggers live in `session-audit-triggers.json` (grow them). The
transcript format is internal to Claude Code: the parsers skip what they do not recognise.

## Smoke test

```bash
echo '{"hook_event_name":"Stop","cwd":"'"$PWD"'"}' | ~/.claude/hooks/notify-banner.sh   # banner unless this pane is focused
echo '{"hook_event_name":"Stop","cwd":"'"$PWD"'"}' | ~/.claude/hooks/agent-mgr-hook claude stop; echo $?   # 0
echo '{"hook_event_name":"SessionStart","cwd":"'"$PWD"'"}' | ~/.claude/hooks/cbm-index-check   # index used, or a warning
echo '{"hook_event_name":"PreToolUse","cwd":"'"$PWD"'","tool_name":"Bash","tool_input":{"command":"cd . && grep -rn SomeSymbol ."}}' | ~/.claude/hooks/cbm-hook-augment   # graph hint
```

## `statusline-command.sh`

The status line under Claude Code's prompt, in the starship prompt's colours: `user@host` over SSH,
the last three folders, the branch (with a red `[+!?]` for staged, modified or untracked changes),
the model and a context-window meter:

     dev/app/ui-cleanup │  ui-cleanup │ 󰚩 Opus 5.5 │ ██████░░░░ 64% 640k/1.0M

The meter is green under 60%, amber to 80% and red above it: amber is the cue to write a handoff,
red to `/clear` and `/pickup`. It reads `context_window` from the status JSON, falling back to the
last usage entry in the transcript. On `main` or `master` the branch shows as a red `⚠`, since work
belongs on a branch of its own. `make claude` sets `statusLine` in `settings.json` to run it. It
needs `jq`, and a Nerd Font in the terminal for the folder, branch and model glyphs.
