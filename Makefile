DOTFILES := $(CURDIR)
UNAME := $(shell uname -s)

.PHONY: init osx linux universal-dots osx-dots agents agent-sync tpm homebrew apt-packages backup bootstrap karabiner

# Bootstrap: ensure stow is installed before anything else
bootstrap:
ifeq ($(UNAME),Darwin)
	@command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
	@command -v stow >/dev/null || brew install stow
else ifeq ($(UNAME),Linux)
	@command -v stow >/dev/null || sudo apt-get install -y stow
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
	$(HOME)/.local/bin/agent-mgr \
	$(HOME)/.local/bin/agent-sync \
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

osx: universal-dots agents osx-dots karabiner tpm agent-sync

osx-dots:
	stow --restow --no-folding --ignore ".DS_Store" --target="$(HOME)" --dir="$(DOTFILES)" osx

linux: universal-dots agents tpm

universal-dots:
	stow --restow --no-folding --ignore ".DS_Store" --target="$(HOME)" --dir="$(DOTFILES)" universal

# .agents is not plain-stowed (see universal/.stow-local-ignore). Skills must be
# DIRECTORY symlinks — Codex ignores a real dir that merely contains a symlinked
# SKILL.md — so the `skills` package is stowed WITH folding into both
# ~/.agents/skills and ~/.claude/skills. AGENTS.md links into ~/.agents only.
# ~/.claude/skills stays a real dir (owned by universal-dots), so folding just
# our entries leaves any other skills alone.
agents:
	@agents_src="$(DOTFILES)/universal/.agents"; \
	for target in "$(HOME)/.agents/skills" "$(HOME)/.claude/skills"; do \
		mkdir -p "$$target"; \
		for skill in "$$agents_src/skills"/*/; do \
			s="$$(basename "$$skill")"; \
			if [ -d "$$target/$$s" ] && [ ! -L "$$target/$$s" ]; then rm -rf "$$target/$$s"; fi; \
		done; \
	done; \
	stow --restow --no-folding --ignore ".DS_Store" --ignore "skills" \
		--target="$(HOME)/.agents" --dir="$(DOTFILES)/universal" .agents; \
	stow --restow --ignore ".DS_Store" --target="$(HOME)/.agents/skills" --dir="$$agents_src" skills; \
	stow --restow --ignore ".DS_Store" --target="$(HOME)/.claude/skills" --dir="$$agents_src" skills

karabiner:
	@mkdir -p "$(HOME)/.config/karabiner"
	cp "$(DOTFILES)/extra/karabiner/karabiner.json" "$(HOME)/.config/karabiner/karabiner.json"

# Install + load the agent-sync LaunchAgent (macOS): git-syncs ~/agents with
# its private GitHub remote every 15 min. The plist is a template — __HOME__ is
# sed-substituted because launchd expands no variables and usernames differ
# across machines — and copied (not stowed) since launchd refuses symlinked
# plists. bootout-then-bootstrap keeps it idempotent.
agent-sync:
	@src="$(DOTFILES)/extra/launchd/com.pete.agent-sync.plist"; \
	dst="$(HOME)/Library/LaunchAgents/com.pete.agent-sync.plist"; \
	if [ "$(UNAME)" = "Darwin" ] && [ -f "$$src" ]; then \
		mkdir -p "$(HOME)/Library/LaunchAgents" "$(HOME)/.local/state"; \
		sed "s|__HOME__|$(HOME)|g" "$$src" > "$$dst"; \
		domain="gui/$$(id -u)"; \
		launchctl bootout "$$domain/com.pete.agent-sync" 2>/dev/null || true; \
		launchctl bootstrap "$$domain" "$$dst"; \
	fi

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
		xargs -a "$(DOTFILES)/extra/apt/packages.txt" sudo apt-get install -y; \
	else \
		echo "No apt packages file found at extra/apt/packages.txt"; \
	fi
