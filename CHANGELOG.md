# Changelog

All notable changes to this dotfiles repo. Newest entries on top.

Format: `YYYY-MM-DD — short description`. Group related changes under one date.

## 2026-08-08

- Tmux: `@tpm_plugins` now points at `petrogad/tmux-agent-mgr` instead of `alexciarlillo/tmux-agent-mgr`. Forked to add a global notes scratchpad to the agent sidebar — a bottom panel of short note titles with a detail overlay, so context noticed mid-agent-run has somewhere to go. Upstream's `CLAUDE.md` lists "a bottom panel" as explicitly out of scope, so this lives on the fork rather than as a PR. The fork tracks upstream as the `upstream` remote; sync with `git fetch upstream && git merge upstream/main` in `~/.config/tmux/plugins/tmux-agent-mgr`. Work in progress on the `notes-panel` branch — the storage layer and `agent-mgr note add|list|show` are done, the UI panel is not.

## 2026-08-07

- Tmux: added TPM plugin management to `tmux.conf.user` via the `@tpm_plugins` list (gpakosz's conf sources it through `if-shell`, so `set -g @plugin` entries are invisible to TPM) with `tmux-resurrect` + `tmux-continuum` — sessions auto-save every 10 min, capture pane contents, and auto-restore on server start — plus `alexciarlillo/tmux-agent-mgr`. TPM init runs at the very bottom of the file so plugin status-line hooks aren't clobbered by the Appearance block. New `make tpm` target clones TPM and installs plugins idempotently; `universal/.config/tmux/.gitignore` keeps `plugins/` out of git.
- Tmux: `prefix C-f` opens a fuzzy session switcher popup (`universal/.local/bin/tmux-session-popup`, fzf-based, previews windows, most-recent first). `fzf` added to Brewfile.
- Agents: added `universal/.agents/` — `AGENTS.md` (agent-agnostic standing instructions; Codex reads it natively, `~/.claude/CLAUDE.md` stubs import it) and the `research → plan → handoff → pickup` skill suite plus shared `agent-docs` conventions. New `make agents` target stows `AGENTS.md` into `~/.agents` and folds the skills as directory symlinks into both `~/.agents/skills` and `~/.claude/skills`. Removed the superseded `universal/.claude/skills/handoff`.
- Agents: `~/agents` workspace now syncs between machines via a private GitHub repo (`petrogad/agents`). New git-based `universal/.local/bin/agent-sync` (commit → pull --rebase → push; lock-guarded, offline-safe, aborts and logs on rebase conflict) driven by a launchd agent every 15 min. The plist (`extra/launchd/com.pete.agent-sync.plist`) is a `__HOME__` template sed-substituted by the new `make agent-sync` target, since launchd expands no variables and usernames differ across machines.
- Zsh: nvm switched from Homebrew to `znap source lukechilds/zsh-nvm` (lazy load, auto-`nvm use`, cross-platform); dropped `brew "nvm"` from the Brewfile. Added a generic `env.d`/`interactive.d` drop-in loader to `.zshrc`. Aliases: fuller `ssh-clean-mouse` escape reset + `stty sane`, new `fix` alias for garbled terminals, and `cyolo` (`codex --yolo`) alongside `yolo`.
- Makefile: all stow calls now use `--no-folding`; `osx` target is `universal-dots agents osx-dots karabiner tpm agent-sync` (dropped the broken `hammerspoon-pre-dots` reference); `linux` is `universal-dots agents tpm`.
- Git: added `[include] path = ~/.gitconfig.local` for machine-local config.
- WezTerm: `Cmd+Shift+H` opens a tab ssh'd into helios via system ssh (honors `~/.ssh/config` ProxyCommand + ControlMaster).
- Removed work-specific remnants: Roblox branch-prefixing logic in `_worktree`/`_worktree-rm` (inert without `RBX_GITHUB_USER`), and all `declawd` references (aliases yolo fallback, pre-commit agent chain, notify-tmux pane matcher).
- `osx/.config/linearmouse/linearmouse.json`: updated to current schema with latest pointer settings.

## 2026-07-24

- Added an SSH indicator to the Starship prompt: `$username$hostname` now lead the format in `universal/.config/starship.toml`, with `ssh_only = true` on hostname and default `show_always = false` on username. Locally the prompt is unchanged; over SSH it prefixes a bold-yellow `user@🌐 hostname`.
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
