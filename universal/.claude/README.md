# Claude Code dotfiles

Stowed bits of `~/.claude/`: two hook scripts. `make claude` (run by `make osx` / `make linux`)
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

## Smoke test

```bash
echo '{"hook_event_name":"Stop","cwd":"'"$PWD"'"}' | ~/.claude/hooks/notify-banner.sh   # banner unless this pane is focused
echo '{"hook_event_name":"Stop","cwd":"'"$PWD"'"}' | ~/.claude/hooks/agent-mgr-hook claude stop; echo $?   # 0
```
