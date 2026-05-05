# Changelog

All notable changes to this dotfiles repo. Newest entries on top.

Format: `YYYY-MM-DD — short description`. Group related changes under one date.

## 2026-05-05

- Anchored `.gitignore` `.claude` rule to the repo root (`/.claude/`) so `universal/.claude/` is no longer ignored. The Claude Code tmux notify hook (`notify-tmux.sh`) and its README were silently untracked, which is why fresh machines never got `~/.claude/hooks/notify-tmux.sh` after `make osx`. Begin tracking `universal/.claude/`.
- Added `CHANGELOG.md` and wired it into `CLAUDE.md` so future changes get recorded.
- Credited [alexciarlillo/dotfiles](https://github.com/alexciarlillo/dotfiles) in the README as the inspiration for this setup.
- Rewrote `CLAUDE.md` to document the Makefile commands, the three package directories, the edit-symlink-edits-repo invariant, and the Karabiner GUI write-back gotcha.
- Added `README.md` with a multi-machine workflow guide.
