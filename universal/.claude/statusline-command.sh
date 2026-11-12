#!/bin/bash
# Claude Code status line: mirrors the starship prompt (~/.config/starship.toml)
# plus a context-window meter. Reads the status JSON on stdin.
input=$(cat)
j() { echo "$input" | jq -r "$1" 2>/dev/null; }

R='\033[0m'; DIM='\033[2m'; SEP=$(printf "${DIM} │ ${R}")

cwd=$(j '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd=$PWD

# --- user@host, only over SSH (starship: ssh_only) ---
host=""
[ -n "$SSH_CONNECTION" ] && host=$(printf '\033[1;33m%s@%s\033[0m' "$(whoami)" "$(hostname -s)")

# --- directory: last 3 components, ~ for home (starship: truncation_length = 3) ---
d=${cwd/#$HOME/\~}
IFS='/' read -ra parts <<< "$d"
n=${#parts[@]}
[ "$n" -gt 3 ] && d="${parts[$((n-3))]}/${parts[$((n-2))]}/${parts[$((n-1))]}"
dir=$(printf '\033[36m %s\033[0m' "$d")

# --- git branch + status (no optional locks) ---
git_part=""
if branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null); then
  st=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  flags=""
  echo "$st" | grep -q '^[MADRC]' && flags="${flags}+"
  echo "$st" | grep -q '^.[MD]'   && flags="${flags}!"
  echo "$st" | grep -q '^??'      && flags="${flags}?"
  # On the primary branch, warn: work belongs on a branch of its own.
  case "$branch" in
    main|master) git_part=$(printf '\033[1;31m⚠  %s\033[0m' "$branch") ;;
    *)           git_part=$(printf '\033[35m %s\033[0m' "$branch") ;;
  esac
  [ -n "$flags" ] && git_part="$git_part$(printf ' \033[31m[%s]\033[0m' "$flags")"
fi

# --- model ---
model=$(j '.model.display_name // empty')
[ -n "$model" ] && model=$(printf '\033[34m󰚩 %s\033[0m' "$model")

# --- context window: used tokens, size, percentage ---
size=$(j '.context_window.context_window_size // empty')
[ -z "$size" ] && size=200000
pct=$(j '.context_window.used_percentage // empty')
used=$(j '.context_window.used_tokens // .context_window.total_tokens // empty')
if [ -z "$used" ]; then
  tp=$(j '.transcript_path // empty')
  if [ -n "$tp" ] && [ -r "$tp" ]; then
    used=$(tail -n 200 "$tp" | jq -rs '[.[] | (.message.usage // empty)] | last
      | if . then ((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)) else empty end' 2>/dev/null)
  fi
fi
[ -z "$used" ] && [ -n "$pct" ] && used=$(awk -v p="$pct" -v s="$size" 'BEGIN{printf "%d", p*s/100}')
[ -z "$pct" ] && [ -n "$used" ] && pct=$(awk -v u="$used" -v s="$size" 'BEGIN{printf "%.1f", u*100/s}')

human() { awk -v n="$1" 'BEGIN{ if (n>=1000000) printf "%.1fM", n/1000000; else if (n>=1000) printf "%dk", n/1000; else printf "%d", n }'; }

ctx=""
if [ -n "$pct" ]; then
  p=$(printf '%.0f' "$pct")
  if   [ "$p" -gt 80 ]; then c='\033[31m'        # red   > 80
  elif [ "$p" -ge 60 ]; then c='\033[38;5;214m'  # amber 60-80
  else                       c='\033[32m'        # green < 60
  fi
  w=10; f=$(( (p * w + 50) / 100 )); [ "$f" -gt $w ] && f=$w
  bar=""; for ((i=0; i<w; i++)); do [ $i -lt $f ] && bar+="█" || bar+="░"; done
  amt=""
  [ -n "$used" ] && amt=$(printf " ${DIM}%s/%s${R}" "$(human "$used")" "$(human "$size")")
  ctx=$(printf "${c}%s %s%%${R}%s" "$bar" "$p" "$amt")
fi

out=""
for seg in "$host" "$dir" "$git_part" "$model" "$ctx"; do
  [ -z "$seg" ] && continue
  [ -n "$out" ] && out+="$SEP"
  out+="$seg"
done
printf '%b\n' "$out"
