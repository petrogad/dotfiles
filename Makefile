DOTFILES := $(CURDIR)
# The private half (petrogad/dotfiles-private), cloned beside this repo.
PRIVATE ?= $(abspath $(DOTFILES)/../dotfiles-private)
UNAME := $(shell uname -s)

.PHONY: init osx linux universal-dots osx-dots agents private agent-sync agent-workspace claude tpm homebrew apt-packages backup bootstrap karabiner

# Bootstrap: ensure stow is installed before anything else
bootstrap:
ifeq ($(UNAME),Darwin)
	@command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
	@command -v stow >/dev/null || brew install stow
else ifeq ($(UNAME),Linux)
	@command -v stow >/dev/null || sudo apt-get install -y stow
	@# GitHub CLI isn't in Debian's repos, so apt needs its source before
	@# `make apt-packages` can resolve the `gh` line. Idempotent.
	@if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then \
		echo "==> Adding the GitHub CLI apt source"; \
		sudo mkdir -p -m 755 /etc/apt/keyrings; \
		wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
			| sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null; \
		sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
			| sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null; \
	fi
	@# Debian 13 ships postgresql-client 17, but our servers run 18 — and
	@# pg_dump REFUSES a newer server outright ("aborting because of server
	@# version mismatch"). PGDG's metapackage tracks the latest, and a newer
	@# client against an older server is always fine, so this stays correct
	@# when the servers move again.
	@if ! ls /etc/apt/sources.list.d/pgdg.* >/dev/null 2>&1; then \
		echo "==> Adding the PostgreSQL (PGDG) apt source"; \
		sudo apt-get install -y postgresql-common; \
		sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y; \
	fi
	@# Rust from rustup, not the distro. Debian 13 has rustc 1.85 and
	@# tmux-agent-mgr's dependencies need 1.88, so the plugin's first-load
	@# build fails and the sidebar never opens. env.d/rust.zsh puts
	@# ~/.cargo/bin first on PATH so this wins over any distro cargo.
	@if [ ! -x "$$HOME/.cargo/bin/cargo" ]; then \
		echo "==> Installing the Rust toolchain (rustup)"; \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
			| sh -s -- -y --no-modify-path; \
	fi
	@sudo apt-get update -qq
endif

BACKUP_DIR := $(HOME)/dotfiles-backup/$(shell date +%Y%m%d-%H%M%S)

BACKUP_TARGETS := \
	$(HOME)/.zshrc \
	$(HOME)/.tmux.conf \
	$(HOME)/.wezterm.lua \
	$(HOME)/.gitconfig \
	$(HOME)/.gitignore_global \
	$(HOME)/.ripgreprc \
	$(HOME)/.aerospace.toml \
	$(HOME)/.config/starship.toml \
	$(HOME)/.config/karabiner/karabiner.json \
	$(HOME)/.config/lazygit/config.yml \
	$(HOME)/.config/lazygit/shell_init.sh \
	$(HOME)/.config/linearmouse/linearmouse.json \
	$(HOME)/.config/zsh/aliases \
	$(HOME)/.config/zsh/env.d/editor.zsh \
	$(HOME)/.config/zsh/agents \
	$(HOME)/.config/zsh/git \
	$(HOME)/.config/zsh/tmux \
	$(HOME)/.config/tmux/tmux.conf.user \
	$(HOME)/.hammerspoon/init.lua \
	$(HOME)/.agents/AGENTS.md \
	$(HOME)/.claude/CLAUDE.md \
	$(HOME)/.local/bin/agent-mgr \
	$(HOME)/.local/bin/agent-sync \
	$(HOME)/.local/bin/agent-workspace-init \
	$(HOME)/.local/bin/tmux-session-popup

backup:
	@mkdir -p "$(BACKUP_DIR)"
	@for f in $(BACKUP_TARGETS); do \
		if [ -e "$$f" ] && [ ! -L "$$f" ]; then \
			dir="$(BACKUP_DIR)/$$(dirname "$$f" | sed "s|$(HOME)/||")"; \
			mkdir -p "$$dir"; \
			cp "$$f" "$$dir/"; \
			echo "Backed up $$f"; \
		fi; \
	done
	@echo "Backup saved to $(BACKUP_DIR)"

ifeq ($(UNAME),Darwin)
init: bootstrap homebrew
else ifeq ($(UNAME),Linux)
init: bootstrap apt-packages
else
init:
	@echo "Unsupported OS: $(UNAME)"
	@exit 1
endif

osx: universal-dots private agents osx-dots karabiner tpm claude agent-sync agent-workspace

osx-dots:
	stow --restow --no-folding --ignore ".DS_Store" --target="$(HOME)" --dir="$(DOTFILES)" osx

linux: universal-dots private agents tpm claude agent-sync agent-workspace

universal-dots:
	stow --restow --no-folding --ignore ".DS_Store" --target="$(HOME)" --dir="$(DOTFILES)" universal

# .agents is not plain-stowed (see universal/.stow-local-ignore). Skills must be
# DIRECTORY symlinks — Codex ignores a real dir that merely contains a symlinked
# SKILL.md — so each `skills` package is stowed WITH folding into both
# ~/.agents/skills and ~/.claude/skills. ~/.claude/skills stays a real dir
# (owned by universal-dots), so folding just our entries leaves any other skills
# alone. The private repo's skills (if it is cloned) are stowed the same way.
#
# ~/.agents/AGENTS.md is BUILT, not linked: the public AGENTS.md, then the
# private overlay appended when $(PRIVATE) exists — so machine names, addresses
# and accounts never land in this public repo. Edit the sources and re-run.
#
# Codex reads its global instructions from $CODEX_HOME/AGENTS.md (~/.codex), not
# ~/.agents, and installers such as codebase-memory-mcp write marked blocks
# (<!-- name:start --> … <!-- name:end -->) into that same file. So it is a COPY
# of the built file with those blocks carried over, rebuilt on every run, and not
# a symlink, which would let an installer write into the built file. A file there
# with any other content of its own is left alone with a message.
#
# ~/.claude/CLAUDE.md is symlinked at the built file rather than being a stub
# that imports it: Claude Code reads that path as user-level memory whatever it
# contains, so a symlink needs no import syntax to be right. A real file there is
# somebody's own memory and is left alone with a message.
agents:
	@agents_src="$(DOTFILES)/universal/.agents"; priv_src="$(PRIVATE)/agents"; \
	for target in "$(HOME)/.agents/skills" "$(HOME)/.claude/skills"; do \
		mkdir -p "$$target"; \
		find "$$target" -maxdepth 1 -type l ! -exec test -e {} \; -exec rm {} \; ; \
		for skill in "$$agents_src/skills"/*/ "$$priv_src/skills"/*/; do \
			[ -d "$$skill" ] || continue; \
			s="$$(basename "$$skill")"; \
			if [ -d "$$target/$$s" ] && [ ! -L "$$target/$$s" ]; then rm -rf "$$target/$$s"; fi; \
		done; \
		stow --restow --ignore ".DS_Store" --target="$$target" --dir="$$agents_src" skills; \
		if [ -d "$$priv_src/skills" ]; then \
			stow --restow --ignore ".DS_Store" --target="$$target" --dir="$$priv_src" skills; \
		fi; \
	done; \
	built="$(HOME)/.agents/AGENTS.md"; \
	rm -f "$$built"; \
	{ printf '<!-- Built by `make agents` from %s' "$$agents_src/AGENTS.md"; \
	  if [ -f "$$priv_src/AGENTS.md" ]; then printf ' + %s' "$$priv_src/AGENTS.md"; fi; \
	  printf '. Do not edit here. -->\n\n'; \
	  cat "$$agents_src/AGENTS.md"; \
	  if [ -f "$$priv_src/AGENTS.md" ]; then printf '\n'; cat "$$priv_src/AGENTS.md"; fi; \
	} > "$$built"; \
	if [ ! -f "$$priv_src/AGENTS.md" ]; then echo "agents: no $$priv_src/AGENTS.md — built the public part only."; fi; \
	codex_home="$${CODEX_HOME:-$(HOME)/.codex}"; codex_md="$$codex_home/AGENTS.md"; \
	if [ -d "$$codex_home" ]; then \
		own=""; \
		if [ -f "$$codex_md" ] && ! head -1 "$$codex_md" | grep -q '^<!-- Built by `make agents`'; then \
			own="$$(awk '/^<!-- [A-Za-z0-9_.-]+:start -->/{f=1} !f && NF {print} /^<!-- [A-Za-z0-9_.-]+:end -->/{f=0}' "$$codex_md")"; \
		fi; \
		if [ -n "$$own" ]; then \
			echo "agents: $$codex_md has content of its own — leaving it alone."; \
			echo "        Move that content into AGENTS.md (or the private overlay) and re-run."; \
		else \
			tmp="$$(mktemp)"; cp "$$built" "$$tmp"; \
			if [ -f "$$codex_md" ]; then \
				awk '/^<!-- [A-Za-z0-9_.-]+:start -->/{f=1; print ""} f {print} /^<!-- [A-Za-z0-9_.-]+:end -->/{f=0}' "$$codex_md" >> "$$tmp"; \
			fi; \
			rm -f "$$codex_md"; mv "$$tmp" "$$codex_md"; chmod 644 "$$codex_md"; \
		fi; \
	fi; \
	claude_md="$(HOME)/.claude/CLAUDE.md"; \
	if [ -e "$$claude_md" ] && [ ! -L "$$claude_md" ]; then \
		echo "agents: $$claude_md exists and is not a symlink — leaving it alone."; \
		echo "        Move it aside and re-run to have AGENTS.md reach Claude Code."; \
	else \
		ln -sfn "$$built" "$$claude_md"; \
	fi

# Stow the private repo's home/ package into $HOME, if it is cloned. A no-op
# otherwise, so a fresh machine without access still gets a working setup.
private:
	@if [ -d "$(PRIVATE)/home" ]; then \
		stow --restow --no-folding --ignore ".DS_Store" --target="$(HOME)" --dir="$(PRIVATE)" home; \
	else \
		echo "private: $(PRIVATE) not cloned — skipping."; \
	fi

karabiner:
	@mkdir -p "$(HOME)/.config/karabiner"
	cp "$(DOTFILES)/extra/karabiner/karabiner.json" "$(HOME)/.config/karabiner/karabiner.json"

# Install the agent-sync timer: git-syncs ~/agents with its private remote every
# 15 min. macOS: a LaunchAgent. The plist is a template — __HOME__ is
# sed-substituted because launchd expands no variables and usernames differ
# across machines — and copied (not stowed) since launchd refuses symlinked
# plists. bootout-then-bootstrap keeps it idempotent. Linux: a systemd user
# timer, plus lingering so it runs without an open login session.
agent-sync:
	@if [ "$(UNAME)" = "Darwin" ]; then \
		src="$(DOTFILES)/extra/launchd/com.pete.agent-sync.plist"; \
		dst="$(HOME)/Library/LaunchAgents/com.pete.agent-sync.plist"; \
		mkdir -p "$(HOME)/Library/LaunchAgents" "$(HOME)/.local/state"; \
		sed "s|__HOME__|$(HOME)|g" "$$src" > "$$dst"; \
		domain="gui/$$(id -u)"; \
		launchctl bootout "$$domain/com.pete.agent-sync" 2>/dev/null || true; \
		launchctl bootstrap "$$domain" "$$dst"; \
	elif command -v systemctl >/dev/null 2>&1; then \
		dst="$(HOME)/.config/systemd/user"; \
		mkdir -p "$$dst" "$(HOME)/.local/state"; \
		cp "$(DOTFILES)/extra/systemd/agent-sync.service" "$(DOTFILES)/extra/systemd/agent-sync.timer" "$$dst/"; \
		systemctl --user daemon-reload; \
		systemctl --user enable --now agent-sync.timer; \
		loginctl enable-linger "$$(id -un)" 2>/dev/null || \
			echo "agent-sync: could not enable lingering; the timer only runs while you are logged in (sudo loginctl enable-linger $$(id -un))."; \
	fi

# Make ~/agents a clone of $AGENT_WORK_REMOTE (set by dotfiles-private), or
# adopt an existing ~/agents without overwriting anything and pause syncing
# until it is reviewed. A no-op once ~/agents is a repo. See agent-workspace-init.
agent-workspace:
	@"$(DOTFILES)/universal/.local/bin/agent-workspace-init"

# Merge this repo's Claude Code hooks into ~/.claude/settings.json, which is
# never stowed (it holds per-machine state such as enabledPlugins). Adds the
# tmux-agent-mgr forwarder for every event the plugin's hooks.json lists (none
# if TPM hasn't installed it yet, so run after `tpm`) plus the macOS banner, and
# leaves every other hook alone; see extra/claude/merge-hooks.jq. A settings
# file that isn't valid JSON is left untouched with a message.
claude:
	@command -v jq >/dev/null 2>&1 || { echo "claude: jq not installed (make init) — skipping."; exit 0; }; \
	settings="$(HOME)/.claude/settings.json"; mkdir -p "$(HOME)/.claude"; \
	[ -f "$$settings" ] || echo '{}' > "$$settings"; \
	if ! jq -e . "$$settings" >/dev/null 2>&1; then \
		echo "claude: $$settings is not valid JSON — leaving it alone."; exit 0; \
	fi; \
	agentmgr=/dev/null; \
	for d in "$${XDG_CONFIG_HOME:-$(HOME)/.config}/tmux/plugins/tmux-agent-mgr" "$(HOME)/.tmux/plugins/tmux-agent-mgr"; do \
		[ -f "$$d/hooks/hooks.json" ] && { agentmgr="$$d/hooks/hooks.json"; break; }; \
	done; \
	[ "$$agentmgr" = /dev/null ] && echo "claude: tmux-agent-mgr not installed — wiring the banner only (re-run after make tpm)."; \
	tmp="$$(mktemp)"; \
	if jq --slurpfile agentmgr "$$agentmgr" -f "$(DOTFILES)/extra/claude/merge-hooks.jq" "$$settings" > "$$tmp"; then \
		cmp -s "$$tmp" "$$settings" || { cp "$$settings" "$$settings.bak"; mv "$$tmp" "$$settings"; echo "claude: hooks merged into $$settings (previous copy: settings.json.bak)."; }; \
	fi; \
	rm -f "$$tmp"

# Clone TPM if missing, then install the plugins listed in @tpm_plugins.
# install_plugins reads @tpm_plugins + TMUX_PLUGIN_MANAGER_PATH from the running
# server, so ensure one exists (throwaway session) AND re-source the config onto
# it — an already-running server won't have picked up our vars otherwise. Only
# the temp session is killed, leaving any existing sessions intact.
tpm:
	@if command -v tmux >/dev/null 2>&1; then \
		mkdir -p "$(HOME)/.config/tmux/plugins"; \
		if [ ! -d "$(HOME)/.config/tmux/plugins/tpm" ]; then \
			git clone https://github.com/tmux-plugins/tpm "$(HOME)/.config/tmux/plugins/tpm"; \
		fi; \
		tmux new-session -d -s tpm_bootstrap 2>/dev/null || true; \
		tmux source-file "$(HOME)/.tmux.conf" 2>/dev/null || true; \
		"$(HOME)/.config/tmux/plugins/tpm/bin/install_plugins" || true; \
		tmux kill-session -t tpm_bootstrap 2>/dev/null || true; \
	fi

homebrew:
	brew bundle --no-upgrade --file="$(DOTFILES)/extra/homebrew/Brewfile"

apt-packages:
	@if [ -f "$(DOTFILES)/extra/apt/packages.txt" ]; then \
		grep -vE '^[[:space:]]*(#|$$)' "$(DOTFILES)/extra/apt/packages.txt" \
			| xargs sudo apt-get install -y; \
	else \
		echo "No apt packages file found at extra/apt/packages.txt"; \
	fi
	@# Debian renames two of these to avoid clashing with other packages:
	@# bat -> batcat, fd-find -> fdfind. Every doc, alias and muscle memory
	@# says bat and fd, so put those names back.
	@for pair in batcat:bat fdfind:fd; do \
		have=$${pair%%:*}; want=$${pair##*:}; \
		if command -v $$have >/dev/null 2>&1 && ! command -v $$want >/dev/null 2>&1; then \
			echo "==> linking $$want -> $$have"; \
			sudo ln -sf "$$(command -v $$have)" /usr/local/bin/$$want; \
		fi; \
	done
