DOTFILES := $(CURDIR)
SPOONS_DIR := osx/.hammerspoon/Spoons
UNAME := $(shell uname -s)

.PHONY: init osx linux universal homebrew apt-packages hammerspoon-pre-dots bootstrap karabiner backup

# Bootstrap: ensure stow is installed before anything else
bootstrap:
ifeq ($(UNAME),Darwin)
	@command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
	@command -v stow >/dev/null || brew install stow
else ifeq ($(UNAME),Linux)
	@command -v stow >/dev/null || sudo apt-get install -y stow
endif

BACKUP_DIR := $(HOME)/dotfiles-backup/$(shell date +%Y%m%d-%H%M%S)

# Files that stow will manage (add to this list as dotfiles grow)
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
	$(HOME)/.config/zsh/agents \
	$(HOME)/.config/zsh/git \
	$(HOME)/.config/zsh/tmux \
	$(HOME)/.config/tmux/tmux.conf.user \
	$(HOME)/.hammerspoon/init.lua

# Back up existing dotfiles before stow replaces them
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

osx: universal-dots hammerspoon-pre-dots osx-dots karabiner

osx-dots:
	stow --restow --ignore ".DS_Store" --target="$(HOME)" --dir="$(DOTFILES)" osx

karabiner:
	@mkdir -p "$(HOME)/.config/karabiner"
	cp "$(DOTFILES)/extra/karabiner/karabiner.json" "$(HOME)/.config/karabiner/karabiner.json"

linux: universal-dots linux-dots

linux-dots:
	stow --restow --ignore ".DS_Store" --target="$(HOME)" --dir="$(DOTFILES)" linux

universal-dots:
	stow --restow --ignore ".DS_Store" --target="$(HOME)" --dir="$(DOTFILES)" universal

# hammerspoon-pre-dots:
# 	for url in $(shell cat extra/hammerspoon/spoon-zip-urls); do \
# 		curl -sSL -o $(SPOONS_DIR)/$$(basename $$url) $$url && \
# 		unzip -qo $(SPOONS_DIR)/$$(basename $$url) -d $(SPOONS_DIR)/ && \
# 		rm $(SPOONS_DIR)/$$(basename $$url); \
# 	done

homebrew:
	brew bundle --no-upgrade --file="$(DOTFILES)/extra/homebrew/Brewfile"

apt-packages:
	@if [ -f "$(DOTFILES)/extra/apt/packages.txt" ]; then \
		xargs -a "$(DOTFILES)/extra/apt/packages.txt" sudo apt-get install -y; \
	else \
		echo "No apt packages file found at extra/apt/packages.txt"; \
	fi
