#!/usr/bin/env bash
# Self-check for extra/guard/public-guard, in a throwaway repo.
#   bash tests/public-guard.sh
# Every fixture string below is fake; this file is skipped by the guard itself.
set -euo pipefail

src="$(cd "$(dirname "$0")/.." && pwd)/extra/guard"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export GIT_CONFIG_GLOBAL="$work/gitconfig" GIT_CONFIG_NOSYSTEM=1
git config --global user.name test
git config --global user.email test@example.invalid
git config --global init.defaultBranch main

r="$work/dotfiles"
mkdir -p "$r/extra/guard" "$work/dotfiles-private/guard"
cp "$src/public-guard" "$src/patterns.txt" "$r/extra/guard/"
printf 'zephyrhost\n10\\.9\\.8\\.7\n' > "$work/dotfiles-private/guard/denylist.txt"
git -C "$r" init -q
echo clean > "$r/README.md"
git -C "$r" add -A && git -C "$r" commit -q -m init
guard="$r/extra/guard/public-guard"

fail=0
# expect <name> <exit code> <cmd…>: runs in the repo; output must never echo a fixture value
expect() {
  local name="$1" want="$2" got out; shift 2
  set +e; out="$(cd "$r" && "$@" 2>&1)"; got=$?; set -e
  if [ "$got" != "$want" ]; then echo "FAIL - $name (exit $got, want $want)"; echo "$out" | sed 's/^/       /'; fail=1; return; fi
  if printf '%s' "$out" | grep -qiE 'jdoe|zephyrhost|10\.9\.8\.7|session_|ghost@gmail|vault-x|nas\.home'; then
    echo "FAIL - $name (output echoes the matched text)"; fail=1; return
  fi
  echo "ok   - $name"
}

stage() { printf '%s\n' "$1" > "$r/f.txt"; git -C "$r" add f.txt; }

expect "clean staged diff passes"            0 "$guard" --staged
for bad in '/Users/jdoe/bin' '/home/jdoe/x' 'https://claude.ai/code/session_abc' \
           'op read op://vault-x/item/field' 'ssh nas.home.arpa' 'mail ghost@gmail.com'; do
  stage "$bad"; expect "generic: ${bad%% *}…"    1 "$guard" --staged
done
stage 'see op://<vault>/<item>/<field> and $HOME/.config and /home/.config'
expect "placeholders and \$HOME pass"        0 "$guard" --staged
stage 'ssh zephyrhost'; expect "private list from ../dotfiles-private" 1 "$guard" --staged
stage 'ping 10.9.8.7';  expect "private address"  1 "$guard" --staged

# Without the private repo: generic only, says so, still passes a private-only value.
mv "$work/dotfiles-private" "$work/elsewhere"
stage 'ssh zephyrhost'; expect "no private list: generic only" 0 "$guard" --staged
# PUBLIC_GUARD_DENYLIST (how CI passes the secret) replaces the repo lookup.
expect "PUBLIC_GUARD_DENYLIST file" 1 env PUBLIC_GUARD_DENYLIST="$work/elsewhere/guard/denylist.txt" "$guard" --staged
expect "PUBLIC_GUARD_DENYLIST missing file is an error" 2 env PUBLIC_GUARD_DENYLIST="$work/nope" "$guard" --staged
mv "$work/elsewhere" "$work/dotfiles-private"

# --revs: added lines and commit messages.
git -C "$r" reset -q --hard
echo fine > "$r/g.txt"; git -C "$r" add g.txt
git -C "$r" commit -q -m "ok" -m "Claude-Session: https://claude.ai/code/session_x"
expect "--revs catches a message trailer"    1 "$guard" --revs -1 HEAD
git -C "$r" reset -q --hard HEAD~1
echo 'zephyrhost' > "$r/g.txt"; git -C "$r" add g.txt; git -C "$r" commit -q -m "plain"
expect "--revs catches an added line"        1 "$guard" --revs -1 HEAD
expect "--tree catches a committed file"     1 "$guard" --tree
git -C "$r" reset -q --hard HEAD~1
expect "--tree clean"                        0 "$guard" --tree

# The pattern file itself is skipped.
echo '# extra' >> "$r/extra/guard/patterns.txt"; git -C "$r" add -A
expect "patterns.txt is not scanned"         0 "$guard" --staged

exit "$fail"
