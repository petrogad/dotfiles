# Claude Code dotfiles

Stowed bits of `~/.claude/`. Two scripts that work together with the twork tmux setup to surface Claude's state at a glance.

## What you see

The tmux window name picks up a status indicator while Claude is running:

| Glyph | State | Set on |
|---|---|---|
| `⠋` | working | `UserPromptSubmit` |
| `✓` | finished | `Stop` |
| `?` | needs input | `Notification` |

The same indicator is mirrored across the matching window in both `runtime` and `agent` twork sessions, so you see the state regardless of which one you're attached to.

Focusing a window in the `✓` or `?` state strips the prefix back to the original name. The `⠋` working state is left alone — focusing while Claude is still thinking doesn't change anything.

## `hooks/notify-tmux.sh`

Wired to `UserPromptSubmit`, `Stop`, and `Notification`. On every event it updates the window name across both twork sessions. Then:

- **`UserPromptSubmit`** — silent. No bell, no banner. (You just hit enter; you don't need notified.)
- **`Stop`** — bell + "Claude finished" banner with the Hero sound.
- **`Notification`** — bell + "Claude needs input" banner with the Hero sound.

The bell rings on the originating pane's terminal (`\a` to `/dev/tty`) — combined with `monitor-bell on` in `~/.config/tmux/tmux.conf.user`, this flags non-focused windows in the status line. The macOS banner is suppressed when the originating pane is the currently-focused pane in any attached client (no banner spam while you're already looking at the response).

## `hooks/tmux-clear-indicator.sh`

Wired into tmux's `after-select-window` hook by `twork-init` (in `~/.config/zsh/tmux`). Strips `✓ ` or `? ` prefixes from the focused window's name in both sessions.

## One-time setup per machine

`~/.claude/settings.json` is intentionally **not** stowed (it holds per-machine state like `enabledPlugins`). Merge this into it:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-tmux.sh" }] }
    ],
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
  UserPromptSubmit: [{ hooks: [{ type: "command", command: "~/.claude/hooks/notify-tmux.sh" }] }],
  Stop: [{ hooks: [{ type: "command", command: "~/.claude/hooks/notify-tmux.sh" }] }],
  Notification: [{ hooks: [{ type: "command", command: "~/.claude/hooks/notify-tmux.sh" }] }]
}' ~/.claude/settings.json > ~/.claude/settings.json.new && mv ~/.claude/settings.json.new ~/.claude/settings.json
```

If you already have twork sessions running when you pull this change, the `after-select-window` hook for clearing indicators won't be installed on them. Either restart tmux (`twork-nuke && start a new project`) or manually run the same `tmux set-hook -a ...` commands from `twork-init` against the live sessions.

## Smoke test

```bash
echo '{"hook_event_name":"UserPromptSubmit","cwd":"'"$PWD"'"}' | ~/.claude/hooks/notify-tmux.sh
echo '{"hook_event_name":"Stop","cwd":"'"$PWD"'"}'             | ~/.claude/hooks/notify-tmux.sh
echo '{"hook_event_name":"Notification","cwd":"'"$PWD"'"}'     | ~/.claude/hooks/notify-tmux.sh
```

From inside a tmux pane, each event should flip the indicator on the current window in both runtime + agent sessions. Stop/Notification also bell + banner (when unfocused). UserPromptSubmit is silent.
