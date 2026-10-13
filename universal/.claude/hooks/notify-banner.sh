#!/usr/bin/env bash
# Claude Code Stop / Notification hook: a macOS banner ("Claude finished",
# "Claude needs input") with the Hero sound — unless you are already looking at
# the pane it came from. State inside tmux (tab glyphs, sidebar) is
# tmux-agent-mgr's job; this only covers the case where you are elsewhere.
#
# The pane is $TMUX_PANE when the harness passes it through, otherwise the one
# pane whose foreground command is claude/node in the payload's cwd. "Looking at
# it" means it is the active pane of a window some attached client is showing.
# No-op off macOS.
set -u
[ "$(uname -s)" = "Darwin" ] || { cat >/dev/null; exit 0; }

payload="$(cat)"
event="$(printf '%s' "$payload" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "${cwd:-}" ] && cwd="$PWD"
project="$(basename "$cwd")"

watching() {
  command -v tmux >/dev/null 2>&1 || return 1
  local pane="${TMUX_PANE:-}" active wid
  if [ -z "$pane" ]; then
    pane="$(tmux list-panes -a -F '#{pane_id}|#{pane_current_command}|#{pane_current_path}' 2>/dev/null |
      awk -F'|' -v c="$cwd" '($2=="claude" || $2=="node") && $3==c {p=$1; n++} END {if (n==1) print p}')"
  fi
  [ -n "$pane" ] || return 1
  read -r active wid < <(tmux display-message -p -t "$pane" '#{pane_active} #{window_id}' 2>/dev/null) || return 1
  [ "$active" = 1 ] || return 1
  tmux list-clients -F '#{window_id}' 2>/dev/null | grep -qx "$wid"
}

watching && exit 0

case "$event" in
  Notification) title="Claude needs input" ;;
  *)            title="Claude finished" ;;
esac
osascript -e "display notification \"$project\" with title \"$title\" sound name \"Hero\"" >/dev/null 2>&1 || true
