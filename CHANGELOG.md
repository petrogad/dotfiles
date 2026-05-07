# Changelog

All notable changes to this dotfiles repo. Newest entries on top.

Format: `YYYY-MM-DD — short description`. Group related changes under one date.

## 2026-05-07

- `notify-tmux.sh` no longer depends on `$TMUX` / `$TMUX_PANE` being inherited — some sandboxed harnesses don't propagate them, which silently no-op'd the window-rename and bell branches. Target pane is identified by matching `pane_current_command ∈ {declawd, claude, node}` + `pane_current_path == cwd` (from the hook payload), so manually renamed tmux windows still get tracked. Falls back to `basename(cwd)` when no pane uniquely matches (preserves prior behavior when twork naming is intact). Banner-suppression check uses `tmux list-clients -F '#{window_id}'` to see whether any attached client is already looking at a matching window. Bash-3.2-safe (no `declare -A`).

## 2026-05-05

- Moved work-specific shell helpers and a couple of related env exports out of the tracked dotfiles and into `~/.zshrc.local`, which `.zshrc` already sources and `.stow-local-ignore` deliberately keeps out of the repo. Keeps machine-specific identifiers off the public history going forward.
- Tmux window name reflects Claude's state across `runtime` and `agent` twork sessions: `⠋myproject` working (UserPromptSubmit), bare name + red bell flag for done (Stop), `?myproject` + red bell flag for needs-input (Notification). Indicators are space-less so the after-select-window sync hook still parses `agent:#{window_name}` as one shell token. Done has no glyph — Stop rings the bell on a pane in each matching window and tmux's `monitor-bell` flag handles the red, auto-clearing on focus. `tmux-clear-indicator.sh` strips the `?` prefix on focus; working `⠋` is left alone. Banner sound switched from Glass/Funk to Hero. `~/.claude/settings.json` snippet now requires a `UserPromptSubmit` hook entry — re-merge per the README.
- `twork-new` no longer auto-launches `yolo` (claude) in the agent window — single `ls` pane instead, matching the behavior `_dev_add_project` was updated to in commit 4174054. The split-pane + auto-yolo pattern was missed by that earlier change.
- Anchored `.gitignore` `.claude` rule to the repo root (`/.claude/`) so `universal/.claude/` is no longer ignored. The Claude Code tmux notify hook (`notify-tmux.sh`) and its README were silently untracked, which is why fresh machines never got `~/.claude/hooks/notify-tmux.sh` after `make osx`. Begin tracking `universal/.claude/`.
- Added `CHANGELOG.md` and wired it into `CLAUDE.md` so future changes get recorded.
- Credited [alexciarlillo/dotfiles](https://github.com/alexciarlillo/dotfiles) in the README as the inspiration for this setup.
- Rewrote `CLAUDE.md` to document the Makefile commands, the three package directories, the edit-symlink-edits-repo invariant, and the Karabiner GUI write-back gotcha.
- Added `README.md` with a multi-machine workflow guide.
