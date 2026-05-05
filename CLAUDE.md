# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and a `Makefile`. There is no build, lint, or test suite — changes are validated by re-running `make osx` / `make linux` and opening a fresh shell.

## Changelog discipline

**Every meaningful change to this repo must be recorded in `CHANGELOG.md`** before committing. Add a bullet under today's date (create a new `## YYYY-MM-DD` section if one doesn't exist). Skip the changelog only for trivial edits (typos, whitespace).

## Commands

```bash
make backup    # snapshot existing real files in $HOME to ~/dotfiles-backup/<timestamp>/ (skips symlinks)
make init      # install packages: brew bundle (macOS) or apt-get (Linux). Bootstraps stow if missing.
make osx       # stow universal/ + osx/, copy karabiner.json, run hammerspoon-pre-dots
make linux     # stow universal/ + linux/
```

`make osx` / `make linux` use `stow --restow`, so they're idempotent — re-running just refreshes symlinks. The standard inner-loop after editing a config in this repo is: re-run `make osx` (only needed when adding a new file; existing symlinks already point into the repo).

## Architecture

Stow mirrors `universal/` and `osx/` into `$HOME` as symlinks, preserving the directory structure. So `universal/.config/zsh/aliases` → `~/.config/zsh/aliases`. **Editing a symlinked dotfile in `~` edits the file inside this repo** — that's the intended workflow, not a bug.

Three top-level package directories, each with different semantics:

- **`universal/`** — stowed on every OS. Cross-platform configs (zsh, tmux, git, ripgrep, wezterm, starship, lazygit).
- **`osx/`** — stowed only by `make osx`. macOS-only configs (aerospace, hammerspoon, linearmouse).
- **`extra/`** — **never stowed.** Used by Makefile targets:
  - `extra/homebrew/Brewfile` — consumed by `make init` on macOS
  - `extra/apt/packages.txt` — consumed by `make init` on Linux
  - `extra/karabiner/karabiner.json` — **copied** (not symlinked) by `make osx`, because Karabiner-Elements rewrites its config on launch and would clobber a symlink
  - `extra/dev.sh.sample` — template only, not installed

There is no `linux/` directory yet; `make linux` will fail at the stow step until one exists.

### Adding a new dotfile

1. Place it in `universal/` (or `osx/`) at the path it should occupy under `$HOME`.
2. Add it to `BACKUP_TARGETS` in the `Makefile` so `make backup` preserves any pre-existing version on a fresh machine.
3. Run `make osx` / `make linux` — stow creates the symlink.

If the app rewrites its own config file on launch (Karabiner-style), don't stow it. Put it in `extra/<app>/` and add a `cp` step to the Makefile, modeled on the `karabiner` target.

### `.stow-local-ignore`

Each package has one. Excludes `.DS_Store`, `*.local` files, `README.*`, and `LICENSE` from being symlinked. Notably this means **`.zshrc.local` is intentionally not stowed** — it's sourced by `.zshrc` if present and is the escape hatch for machine-specific config (work laptop paths, secrets) that shouldn't be in the repo.

### Karabiner write-back gotcha

Because Karabiner is copied (not symlinked), GUI changes write to `~/.config/karabiner/karabiner.json` and **do not** propagate to the repo. To save GUI changes:

```bash
cp ~/.config/karabiner/karabiner.json extra/karabiner/karabiner.json
```

### `dev` command

Defined in `universal/.config/zsh/tmux`. Running `dev` (or `dev /path/to/project`) sources a `.dev.sh` from the project directory, which calls `_dev_add_project` to lay out a tmux window. Per-project layouts live in each project's repo, **not here**. `extra/dev.sh.sample` is the template.

## Shell setup

- Plugin manager: **znap** (zsh-snap), not oh-my-zsh
- Prompt: **Starship**, not Powerlevel10k
- Modular configs: `.zshrc` sources `~/.config/zsh/{aliases,git,tmux}`
