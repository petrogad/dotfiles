#!/usr/bin/env bash
# Self-check for universal/.claude/hooks/skill-gate. Builds throwaway transcripts and repos.
#   bash tests/skill-gate.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/universal/.claude/hooks/skill-gate"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fails=0

check() { # check <description> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; fails=$((fails + 1)); fi
}
# decision <transcript> <cwd> <prompt> [subagent_type] -> deny | allow
decision() {
  out="$(jq -n --arg t "$1" --arg c "$2" --arg p "$3" --arg s "${4:-general-purpose}" \
    '{tool_name:"Agent",transcript_path:$t,cwd:$c,tool_input:{prompt:$p,subagent_type:$s}}' | "$hook")"
  if echo "$out" | grep -q '"deny"'; then echo deny; else echo allow; fi
}
agent_call='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Agent","input":{"prompt":"x"}}]}}'
skill_call() { echo "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Skill\",\"input\":{\"skill\":\"$1\"}}]}}"; }

plain="$tmp/plain"; mkdir -p "$plain/.git"
repo="$tmp/repo"; mkdir -p "$repo/.git" "$repo/.agents/skills/repo-local-stack"
printf -- '---\nname: repo-local-stack\ndescription: Bring up the stack.\n---\n' > "$repo/.agents/skills/repo-local-stack/SKILL.md"

: > "$tmp/fresh.jsonl"
echo "$agent_call" > "$tmp/one-spawn.jsonl"
{ echo "$agent_call"; skill_call token-economy; skill_call agent-docs; } > "$tmp/loaded.jsonl"
{ echo "$agent_call"; skill_call token-economy; } > "$tmp/half.jsonl"
{ echo "$agent_call"; echo '{"type":"user","message":{"content":"<command-name>/token-economy</command-name>"}}';
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/skills/agent-docs/SKILL.md"}}]}}'; } > "$tmp/other-ways.jsonl"

check "first spawn is allowed"                      allow "$(decision "$tmp/fresh.jsonl" "$plain" "do it")"
check "second spawn without skills is denied"       deny  "$(decision "$tmp/one-spawn.jsonl" "$plain" "do it")"
check "second spawn with one of two is denied"      deny  "$(decision "$tmp/half.jsonl" "$plain" "do it")"
check "second spawn with both loaded is allowed"    allow "$(decision "$tmp/loaded.jsonl" "$plain" "do it")"
check "slash command and Read count as loaded"      allow "$(decision "$tmp/other-ways.jsonl" "$plain" "do it")"
check "brief naming no repo skill is denied"        deny  "$(decision "$tmp/fresh.jsonl" "$repo" "build the page")"
check "brief naming the repo skill is allowed"      allow "$(decision "$tmp/fresh.jsonl" "$repo/sub" "Load repo-local-stack first")"
check "'Skills: none apply' is allowed"             allow "$(decision "$tmp/fresh.jsonl" "$repo" "Skills: none apply. Fix it")"
check "lookup agents skip the brief check"          allow "$(decision "$tmp/fresh.jsonl" "$repo" "find X" Explore)"
fakehome="$tmp/home"; mkdir -p "$fakehome/.claude/skills/global-skill" "$fakehome/dev"
printf -- '---\nname: global-skill\ndescription: g\n---\n' > "$fakehome/.claude/skills/global-skill/SKILL.md"
check "global skills in ~ are not repo skills"      allow "$(HOME="$fakehome" decision "$tmp/fresh.jsonl" "$fakehome/dev" "do it")"
mkdir -p "$tmp/wt/.bare" && mv "$repo" "$tmp/wt/main"
check ".bare root uses the main worktree's skills"  deny  "$(decision "$tmp/fresh.jsonl" "$tmp/wt" "build the page")"
out="$(echo 'not json' | "$hook" 2>&1)" && rc=0 || rc=$?
check "a hook error allows the call, exit 1"        "1" "$rc"

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
