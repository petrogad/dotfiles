#!/usr/bin/env bash
# Self-check for universal/.local/bin/agent-title and universal/.claude/hooks/agent-title-hook.
# Runs on a private tmux server (its own socket), so your sessions are never touched.
#   bash tests/agent-title.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
title="$root/universal/.local/bin/agent-title"
hook="$root/universal/.claude/hooks/agent-title-hook"
sock="$(mktemp -d)/tmux.sock"
fails=0

t() { tmux -S "$sock" "$@"; }
trap 't kill-server 2>/dev/null; rm -rf "$(dirname "$sock")"' EXIT

t new-session -d -s test -n zsh
p1="$(t display -p -t test:zsh '#{pane_id}')"
p2="$(t split-window -d -P -F '#{pane_id}' -t "$p1")"
export TMUX="$sock,0,0" # agent-title's plain `tmux` calls follow $TMUX to this server

name() { t display -p -t "$p1" '#{window_name}'; }
as() { TMUX_PANE="$1" "$title" "$2" 2>&1; }
hook_as() { echo "{\"source\":\"$2\"}" | TMUX_PANE="$1" "$hook"; }
check() { # check <description> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; fails=$((fails + 1)); fi
}

check "hook reminds while unnamed" "1" "$(hook_as "$p1" startup | grep -c 'still unnamed')"
TMUX_PANE="$p1" "$title" "Bad_Name!" 2>/dev/null && rc=0 || rc=$?
check "rejects bad characters" "2" "$rc"
TMUX_PANE="$p1" "$title" "This Name Is Far Too Long" 2>/dev/null && rc=0 || rc=$?
check "rejects over 20 chars" "2" "$rc"

as "$p1" "First Topic" >/dev/null
check "renames a default-named window" "First Topic" "$(name)"
check "hook silent once named" "" "$(hook_as "$p1" startup)"
t set-option -wq -t "$p1" @agent_title_at "$(date +%s)" # the startup hook above cleared it

as "$p1" "Second Topic" >/dev/null
check "cooldown blocks a rename" "First Topic" "$(name)"
hook_as "$p1" resume >/dev/null; as "$p1" "Second Topic" >/dev/null
check "resume keeps the cooldown" "First Topic" "$(name)"
hook_as "$p1" compact >/dev/null; as "$p1" "Second Topic" >/dev/null
check "compact keeps the cooldown" "First Topic" "$(name)"
hook_as "$p2" startup >/dev/null; as "$p1" "Second Topic" >/dev/null
check "another pane's startup keeps it" "First Topic" "$(name)"
hook_as "$p1" clear >/dev/null; as "$p1" "Second Topic" >/dev/null
check "owner's /clear lifts it" "Second Topic" "$(name)"

t set-option -wqu -t "$p1" @agent_title_at
as "$p2" "Other Pane" >/dev/null
check "other pane can't take the name" "Second Topic" "$(name)"
t kill-pane -t "$p1"
p1="$p2"
as "$p2" "Third Topic" >/dev/null
check "owner gone, other pane takes over" "Third Topic" "$(name)"

t rename-window -t "$p2" "Mine"
t set-option -wqu -t "$p2" @agent_title_at
as "$p2" "Fourth" >/dev/null
check "hand-set name left alone" "Mine" "$(name)"

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
