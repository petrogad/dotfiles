# Claude Code dotfiles

Stowed bits of `~/.claude/`. Currently just one thing: a tmux idle-pane notifier.

## `hooks/notify-tmux.sh`

Wired to Claude Code's `Stop` (turn finished) and `Notification` (awaiting input) hooks. When either fires:

- Always rings the tmux bell on the originating pane's terminal (`\a` to `/dev/tty`). Combined with `monitor-bell on` in `~/.config/tmux/tmux.conf.user`, this flags the window in the status line whenever it isn't the one you're looking at.
- If the pane is **not** the currently-focused pane in any attached tmux client, also fires a macOS banner via `osascript`. Two tones:
  - `Stop` → "Claude finished" + Glass sound
  - `Notification` → "Claude needs input" + Funk sound (more urgent — agent is stalled)

The active-pane suppression keeps the pane you're actively working in quiet — no banner spam while you can already see the response.

## One-time setup per machine

`~/.claude/settings.json` is intentionally **not** stowed (it holds per-machine state like `enabledPlugins`). Merge this into it:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-tmux.sh" }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-tmux.sh" }] }
    ]
  }
}
```

Or with `jq`:

```bash
jq '.hooks = {
  Stop: [{ hooks: [{ type: "command", command: "~/.claude/hooks/notify-tmux.sh" }] }],
  Notification: [{ hooks: [{ type: "command", command: "~/.claude/hooks/notify-tmux.sh" }] }]
}' ~/.claude/settings.json > ~/.claude/settings.json.new && mv ~/.claude/settings.json.new ~/.claude/settings.json
```

## Smoke test

```bash
echo '{"hook_event_name":"Stop","cwd":"'"$PWD"'"}' | ~/.claude/hooks/notify-tmux.sh
```

From a non-active tmux pane: window flags red in the status line + macOS banner pops. From the active pane: bell only, no banner.
