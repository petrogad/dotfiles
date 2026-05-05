#!/usr/bin/env bash
# Claude Code hook: surface Claude's state in the tmux window name + bell flag.
# UserPromptSubmit  → window name gets a "⠋" (working) prefix, no bell.
# Stop              → indicator stripped; bell rings in both twork sessions
#                     (tmux's monitor-bell flag turns the window red until focused).
# Notification      → window name gets a "?" (needs input) prefix; bell rings.
# Indicators are intentionally space-less ("⠋myproj") so the existing twork
# after-select-window sync hook still parses the window-name target as a
# single shell token.
set -u

WORKING="⠋"
INPUT="?"

payload="$(cat)"
event="$(printf '%s' "$payload" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "${cwd:-}" ] && cwd="$PWD"
project="$(basename "$cwd")"

strip_indicator() {
  local n="$1"
  n="${n#"$WORKING"}"
  n="${n#"$INPUT"}"
  printf '%s' "$n"
}

# Rename matching-named windows across the runtime + agent twork sessions so
# the indicator (or its absence) shows wherever the user is attached.
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

# Write a BEL byte to the first pane's tty in each matching window. tmux's
# monitor-bell watches pane output for BEL and sets the window-bell flag,
# which window-status-bell-style renders red until the window is focused.
ring_bell_in_sessions() {
  local target="$1" session wid wname clean tty
  for session in runtime agent; do
    while IFS=' ' read -r wid wname; do
      clean="$(strip_indicator "$wname")"
      if [ "$clean" = "$target" ]; then
        tty="$(tmux list-panes -t "$wid" -F '#{pane_tty}' 2>/dev/null | head -n1)"
        [ -n "$tty" ] && [ -w "$tty" ] && printf '\a' >"$tty" 2>/dev/null
      fi
    done < <(tmux list-windows -t "$session" -F '#{window_id} #W' 2>/dev/null)
  done
}

clean_current=""
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  current="$(tmux display-message -p -t "$TMUX_PANE" '#W' 2>/dev/null || true)"
  clean_current="$(strip_indicator "$current")"
  case "$event" in
    UserPromptSubmit) rename_in_sessions "$clean_current" "$WORKING$clean_current" ;;
    Stop)             rename_in_sessions "$clean_current" "$clean_current" ;;
    Notification)     rename_in_sessions "$clean_current" "$INPUT$clean_current" ;;
  esac
fi

# UserPromptSubmit only updates the window — no bell, no banner.
[ "$event" = "UserPromptSubmit" ] && exit 0

# Ring the bell on the matching window in BOTH sessions so the red flag
# shows wherever the user is attached.
[ -n "$clean_current" ] && ring_bell_in_sessions "$clean_current"

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
