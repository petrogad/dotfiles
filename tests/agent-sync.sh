#!/usr/bin/env bash
# Self-check for universal/.local/bin/agent-sync: a throwaway HOME with ~/agents
# and a "private dotfiles" repo, each cloned from a local bare remote.
#   bash tests/agent-sync.sh
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
sync="$repo/universal/.local/bin/agent-sync"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

export HOME="$work/home" TMPDIR="$work/tmp" AGENT_SYNC_LOG="$work/sync.log"
export GIT_CONFIG_GLOBAL="$work/gitconfig" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$TMPDIR"
git config --global user.name test
git config --global user.email test@example.invalid
git config --global init.defaultBranch main

fail=0
check() { if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; fail=1; fi; }

mkrepo() { # mkrepo <bare> <clone>
  git init -q --bare "$1"
  git clone -q "$1" "$2" 2>/dev/null
  git -C "$2" commit -q --allow-empty -m init
  git -C "$2" push -q origin main
}

mkrepo "$work/agents.git" "$HOME/agents"
mkrepo "$work/private.git" "$work/dotfiles-private"
mkdir -p "$work/dotfiles-private/home/.config/zsh/env.d" "$HOME/.config/zsh/env.d"
echo 'export X=1' > "$work/dotfiles-private/home/.config/zsh/env.d/private.zsh"
ln -s "$work/dotfiles-private/home/.config/zsh/env.d/private.zsh" "$HOME/.config/zsh/env.d/private.zsh"

# 1. No arguments: both ~/agents and the private repo (found through the stowed link) sync.
echo plan > "$HOME/agents/plan.md"
"$sync"
check "~/agents change pushed" '[ "$(git -C "$work/agents.git" log --format=%s -1 main)" != init ]'
check "private repo change pushed" '[ "$(git -C "$work/private.git" log --format=%s -1 main)" != init ]'

# 2. A private repo on a branch is left alone; ~/agents still syncs.
git -C "$work/dotfiles-private" checkout -q -b feature
echo wip > "$work/dotfiles-private/wip.txt"
echo more >> "$HOME/agents/plan.md"
before="$(git -C "$work/private.git" rev-parse main)"
"$sync"
check "branch checkout not committed or pushed" '[ "$(git -C "$work/private.git" rev-parse main)" = "$before" ] && [ -n "$(git -C "$work/dotfiles-private" status --porcelain)" ]'
check "~/agents synced despite the skipped repo" '[ -z "$(git -C "$HOME/agents" status --porcelain)" ] && [ "$(git -C "$HOME/agents" rev-parse HEAD)" = "$(git -C "$work/agents.git" rev-parse main)" ]'
check "skip is logged" 'grep -q "not main; skip" "$AGENT_SYNC_LOG"'

# 3. Explicit arguments replace the defaults.
git -C "$work/dotfiles-private" checkout -q main
echo again >> "$HOME/agents/plan.md"
"$sync" "$work/dotfiles-private"
check "only the named dir synced" '[ -n "$(git -C "$HOME/agents" status --porcelain)" ]'

# 4. A missing directory is logged, not fatal.
"$sync" "$work/nope" "$HOME/agents"
check "missing dir logged" 'grep -q "nope is not a git repo" "$AGENT_SYNC_LOG"'
check "later dir still synced" '[ -z "$(git -C "$HOME/agents" status --porcelain)" ]'

exit "$fail"
