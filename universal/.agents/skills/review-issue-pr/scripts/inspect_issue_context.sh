#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+$ ]]; then
  printf 'usage: %s <issue-number>\n' "${0##*/}" >&2
  exit 2
fi

issue_number="$1"
if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  git_command=(git -C "$repo_root")
else
  git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null)" || {
    printf 'error: current directory is not a git worktree or coordinator\n' >&2
    exit 1
  }
  repo_root="$PWD"
  git_command=(git --git-dir="$git_dir")
fi

repo_name="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

printf 'repository\n%s\n\n' "$repo_name"
printf 'repository_root\n%s\n\n' "$repo_root"
printf 'issue\n'
gh issue view "$issue_number" --repo "$repo_name" \
  --json number,title,state,url,author,labels,assignees,body,comments

printf '\nlinked_prs\n'
owner="${repo_name%%/*}"
repo="${repo_name#*/}"
gh api graphql \
  -F owner="$owner" \
  -F repo="$repo" \
  -F number="$issue_number" \
  -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){issue(number:$number){timelineItems(first:100,itemTypes:[CROSS_REFERENCED_EVENT,CONNECTED_EVENT]){nodes{... on CrossReferencedEvent{source{... on PullRequest{number title state url headRefName headRefOid baseRefName baseRefOid body}}}... on ConnectedEvent{subject{... on PullRequest{number title state url headRefName headRefOid baseRefName baseRefOid body}}}}}}}}' \
  --jq '[.data.repository.issue.timelineItems.nodes[] | (.source // .subject) | select(.number != null)] | unique_by(.number)'

printf '\nsearch_candidates\n'
gh pr list --repo "$repo_name" --state all --limit 100 \
  --search "#$issue_number" \
  --json number,title,state,url,headRefName,headRefOid,baseRefName,body

printf '\nworktrees\n'
"${git_command[@]}" worktree list --porcelain
