#!/usr/bin/env bash
# Claude Code hook: rename tmux window with status indicator on
# UserPromptSubmit/Stop/Notification, and (when unfocused) ring the bell + macOS banner.
set -u

WORKING="⠋"   # in-progress
DONE="✓"      # finished
INPUT="?"     # awaiting input

payload="$(cat)"
event="$(printf '%s' "$payload" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "${cwd:-}" ] && cwd="$PWD"
project="$(basename "$cwd")"

strip_indicator() {
  local n="$1"
  n="${n#"$WORKING" }"
  n="${n#"$DONE" }"
  n="${n#"$INPUT" }"
  printf '%s' "$n"
}

# Rename matching-named windows across the runtime + agent twork sessions so
# the indicator shows wherever the user is attached.
rename_in_sessions() {
  local target="$1" newname="$2" session wid wname clean
  for session in runtime agent; do
    while IFS=' ' read -r wid wname; do
      clean="$(strip_indicator "$wname")"
      if [ "$clean" = "$target" ]; then
        tmux rename-window -t "$wid" "$newname"
      fi
    done < <(tmux list-windows -t "$session" -F '#{window_id} #W' 2>/dev/null)
  done
}

if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  current="$(tmux display-message -p -t "$TMUX_PANE" '#W' 2>/dev/null || true)"
  clean_current="$(strip_indicator "$current")"
  case "$event" in
    UserPromptSubmit) rename_in_sessions "$clean_current" "$WORKING $clean_current" ;;
    Stop)             rename_in_sessions "$clean_current" "$DONE $clean_current" ;;
    Notification)     rename_in_sessions "$clean_current" "$INPUT $clean_current" ;;
  esac
fi

# UserPromptSubmit only updates the window — no bell or banner (you just hit enter).
[ "$event" = "UserPromptSubmit" ] && exit 0

# Bell on the controlling terminal so monitor-bell flags non-current windows.
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
else
  title="Claude finished"
fi

osascript -e "display notification \"$ctx — $project\" with title \"$title\" sound name \"Hero\"" >/dev/null 2>&1 || true
