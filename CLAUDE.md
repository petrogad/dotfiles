# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and a Makefile.

## Structure

```
dotfiles/
  universal/     # Cross-platform configs (symlinked to ~/ via stow)
  osx/           # macOS-only configs (symlinked to ~/ via stow)
  extra/         # Not stowed — copied, installed, or used by Makefile targets
    homebrew/    # Brewfile for macOS dependencies
    apt/         # packages.txt for Linux dependencies
    karabiner/   # Copied (not symlinked) due to app quirks
    dev.sh.sample  # Template for per-project .dev.sh files
```

## Install

```bash
git clone <repo> ~/github/dotfiles && cd ~/github/dotfiles
make backup   # back up existing dotfiles to ~/dotfiles-backup/<timestamp>/
make init     # install system packages (brew on macOS, apt on Linux)
make osx      # symlink universal + osx configs, copy karabiner
make linux    # symlink universal + linux configs
```

## Key decisions

- **Stow** symlinks `universal/` and `osx/` (or `linux/`) into `$HOME`, mirroring directory structure.
- **Karabiner** is copied (`cp`) not symlinked because the app overwrites symlinks on launch.
- **`.stow-local-ignore`** in each package excludes `.DS_Store`, `*.local` files, `README.*`, and `LICENSE`.
- **`.zshrc.local`** is sourced if present — use it for machine-specific config that shouldn't be in the repo.
- **`dev` command** (from `zsh/tmux`) sources a `.dev.sh` from the current project directory. Project-specific tmux layouts live in each repo, not here.

## Shell setup

- **Plugin manager**: znap (zsh-snap)
- **Prompt**: Starship (not Powerlevel10k)
- **Modular zsh configs**: `~/.config/zsh/{aliases,git,tmux}` sourced from `.zshrc`

## Tools expected

macOS: brew, stow, tmux, starship, wezterm, aerospace, hammerspoon, karabiner-elements, borders, lazygit, lsd, ripgrep, nvm, pyenv
Linux: stow, tmux, starship, lazygit, lsd, ripgrep

## Adding new dotfiles

1. Place the file in `universal/` or `osx/` mirroring the path relative to `$HOME`.
2. Re-run `make osx` or `make linux` — stow handles the symlink.
3. If the app overwrites symlinks, put the file in `extra/` and add a copy step to the Makefile.
4. Update `BACKUP_TARGETS` in the Makefile if the file should be backed up before install.
