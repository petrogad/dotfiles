# Used by `make claude`. Merges this repo's hooks into ~/.claude/settings.json
# (the input) without touching anyone else's — codebase-memory's, a plugin's,
# your own. Idempotent: our entries are recognised by their command paths,
# removed, and re-added, so a re-run never duplicates and a dropped hook goes.
#
#   $agentmgr — tmux-agent-mgr's hooks/hooks.json, slurped ([] if not installed)

def ours: test("/\\.claude/hooks/(agent-mgr-hook|notify-banner\\.sh|notify-tmux\\.sh|cbm-index-check|agent-node-env|agent-title-hook|skill-gate|secret-guard)");

def add($event; $matcher; $command):
  .hooks[$event] = ((.hooks[$event] // []) +
    [{matcher: $matcher, hooks: [{type: "command", command: $command, timeout: 10}]}]);
def add($event; $command): add($event; ""; $command);

# Drop our old entries, then any group or event left empty by that.
(.hooks // {}) as $h
| .hooks = ($h | with_entries(
    .value |= (map(.hooks |= map(select((.command // "") | ours | not)))
               | map(select(.hooks | length > 0))))
  | with_entries(select(.value | length > 0)))

# agent-mgr: every event its hooks.json registers, with the same argument.
| reduce (($agentmgr[0].hooks // {}) | to_entries[]
          | .key as $event
          | .value[].hooks[].command
          | capture("hook\\.sh\" (?<args>.+)$").args as $args
          | [$event, $args]) as [$event, $args]
    (.; add($event; "\"$HOME/.claude/hooks/agent-mgr-hook\" \($args)"))

# The banner, on the two events that mean "come look".
| add("Stop"; "\"$HOME/.claude/hooks/notify-banner.sh\"")
| add("Notification"; "\"$HOME/.claude/hooks/notify-banner.sh\"")

# Which codebase-memory index serves this .bare repo, and a warning when there is none or it is stale.
| add("SessionStart"; "\"$HOME/.claude/hooks/cbm-index-check\"")
| add("SubagentStart"; "\"$HOME/.claude/hooks/cbm-index-check\"")

# Refuse Bash commands that print decrypted secrets into the transcript.
| add("PreToolUse"; "Bash"; "\"$HOME/.claude/hooks/secret-guard\"")

# node/npm/npx in agent shells: zsh-nvm's lazy stubs break in Claude's shell snapshot.
| add("SessionStart"; "\"$HOME/.claude/hooks/agent-node-env\"")

# Name the tmux window: reset agent-title's cooldown for a new session, remind while it is unnamed.
| add("SessionStart"; "\"$HOME/.claude/hooks/agent-title-hook\"")

# Before a subagent spawn: token-economy + agent-docs loaded, repo skills named in the brief.
| .hooks.PreToolUse = ((.hooks.PreToolUse // []) +
    [{matcher: "Agent", hooks: [{type: "command", command: "\"$HOME/.claude/hooks/skill-gate\"", timeout: 10}]}])

# codebase-memory's hook-augment gives up after 2 s by default (over a thousand timeouts in a few
# weeks, each one a dropped hint). Give it 5 s, and Claude's kill timeout room above that.
| .env.CBM_HOOK_DEADLINE_MS = "5000"
#
# And route it through cbm-hook-augment, which points it at the indexed primary worktree: the
# binary matches indexes by exact directory, so in a branch worktree it never says anything.
# Re-run `make claude` after a codebase-memory upgrade puts its own entries back.
| .hooks |= with_entries(.value |= map(.hooks |= map(
    if ((.command // "") | test("codebase-memory-mcp$")) and any((.args // [])[]; . == "hook-augment")
    then .command = "\"$HOME/.claude/hooks/cbm-hook-augment\"" | del(.args) | .timeout = 8 else . end)))

# The status line: folder, branch, model, and a context-window meter.
| .statusLine = {type: "command", command: "bash \"$HOME/.claude/statusline-command.sh\""}
