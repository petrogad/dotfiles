# Changelog

All notable changes to this dotfiles repo. Newest entries on top.

Format: `YYYY-MM-DD — short description`. Group related changes under one date.

## 2026-07-24

- Fixed HTTPS push authentication in `.gitconfig`. The `[credential]` block reset the helper list and pointed at Git Credential Manager's Intel-Mac path (`/usr/local/share/gcm-core/git-credential-manager`), which doesn't exist here — so after the switch to HTTPS remotes, every push failed with "Authentication failed". Now uses `osxkeychain` as the general helper and `gh auth git-credential` for `github.com`/`gist.github.com` (gh is already in the Brewfile and authenticated via `gh auth login`).
- Added three agent-workflow Claude skills under `universal/.claude/skills/`: `handoff` (compact a session into a pickup document), `plan-to-work-items` (break a plan into numbered, dependency-ordered work item files), and `work-item` (pick up the next available work item and implement it through to a draft PR). Stow already links `universal/.claude/` into `~/.claude/`, so `make osx` / `make linux` installs them — no extra Makefile target needed. Skills reference machine-specific repos and build commands via `$AGENT_READY_WORK_DIR/_setup.md` rather than hardcoding them.
- Added `universal/.config/zsh/agents`, sourced from `.zshrc`: exports `$AGENT_HANDOFF_DIR`, `$AGENT_PLANS_DIR`, `$AGENT_RESEARCH_DIR`, and `$AGENT_READY_WORK_DIR` (all under `~/agents/`) and creates the directories. Added to `BACKUP_TARGETS`.
- Removed the `url.ssh://git@github.com.insteadOf` rewrite from `.gitconfig` — switching to HTTPS for GitHub going forward. Updated the README's clone instructions to the HTTPS URL to match (also friendlier on a brand-new machine with no SSH keys yet).

## 2026-05-27

- Silenced the spammy `'if [ "$(tmux show-environment ...)" ...]; ... fi' returned 1` banner that fired across attached clients on every window switch. The `after-select-window` sync hooks in `universal/.config/zsh/tmux` end with `tmux select-window -t <sibling>:<name> 2>/dev/null` — `2>/dev/null` hides stderr but tmux's `run-shell` still surfaces the non-zero exit code in every client's message line whenever a sibling session lacks the named window. Appended `; true` to each of the three hook bodies so the script always returns 0. To apply in a live session, run `twork-init`'s `tmux set-hook -t <session> after-select-window ...` lines manually or rerun `twork-init` after `twork-nuke`.
- Restored the executable bit on `universal/.local/bin/clean-merged-wt`. The file got committed mode `0644`, so calling it directly (`clean-merged-wt`) hit `zsh: permission denied`. The `git clean-wt` alias still worked because it invokes the script with `sh`, which doesn't need `+x`.

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
