# Used by `make claude`. Merges this repo's hooks into ~/.claude/settings.json
# (the input) without touching anyone else's — codebase-memory's, a plugin's,
# your own. Idempotent: our entries are recognised by their command paths,
# removed, and re-added, so a re-run never duplicates and a dropped hook goes.
#
#   $agentmgr — tmux-agent-mgr's hooks/hooks.json, slurped ([] if not installed)

def ours: test("/\\.claude/hooks/(agent-mgr-hook|notify-banner\\.sh|notify-tmux\\.sh)");

def add($event; $command):
  .hooks[$event] = ((.hooks[$event] // []) +
    [{matcher: "", hooks: [{type: "command", command: $command, timeout: 10}]}]);

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
