#!/usr/bin/env bash
# Claude Code hook: alert when a turn finishes (Stop) or input is awaited (Notification).
# Reads Claude's hook JSON from stdin; emits a tmux bell + (when unfocused) a macOS banner.
set -u

payload="$(cat)"
event="$(printf '%s' "$payload" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "${cwd:-}" ] && cwd="$PWD"
project="$(basename "$cwd")"

# Always ring the tmux bell on the controlling terminal so monitor-bell fires.
# tmux only flags non-current windows in the status line, so this is silent when focused.
printf '\a' >/dev/tty 2>/dev/null || true

# macOS banner — only when this pane is NOT the active pane of an attached client.
ctx="$project"
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  active_panes="$(tmux list-clients -F '#{client_active_pane}' 2>/dev/null || true)"
  case " $active_panes " in
    *" $TMUX_PANE "*) exit 0 ;;
  esac
  ctx="$(tmux display-message -p -t "$TMUX_PANE" '#S:#I.#P' 2>/dev/null || echo "$project")"
fi

if [ "$event" = "Notification" ]; then
  title="Claude needs input"
  sound="Funk"
else
  title="Claude finished"
  sound="Glass"
fi

osascript -e "display notification \"$ctx — $project\" with title \"$title\" sound name \"$sound\"" >/dev/null 2>&1 || true
