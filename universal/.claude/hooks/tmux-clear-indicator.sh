#!/usr/bin/env bash
# Tmux after-select-window hook: when the user focuses a window whose name
# starts with the Done (✓) or Input (?) indicator, strip the prefix in both
# the runtime and agent twork sessions. The Working (⠋) indicator is left
# alone — Claude is still running, focusing the window doesn't change that.
set -u

DONE="✓"
INPUT="?"

name="$(tmux display-message -p '#W' 2>/dev/null || true)"
[ -z "$name" ] && exit 0

case "$name" in
  "$DONE "*|"$INPUT "*) ;;
  *) exit 0 ;;
esac

clean="$name"
clean="${clean#"$DONE" }"
clean="${clean#"$INPUT" }"

for session in runtime agent; do
  while IFS=' ' read -r wid wname; do
    wclean="$wname"
    wclean="${wclean#"$DONE" }"
    wclean="${wclean#"$INPUT" }"
    if [ "$wclean" = "$clean" ]; then
      tmux rename-window -t "$wid" "$clean"
    fi
  done < <(tmux list-windows -t "$session" -F '#{window_id} #W' 2>/dev/null)
done
