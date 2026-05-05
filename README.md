# Dotfiles

My personal dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/) and a `Makefile`.

This README is the cheat sheet for **what to do when I sit down at a new (or another) computer**.

---

## TL;DR — common scenarios

### I'm on a brand new computer

```bash
git clone ssh://git@github.com/petrogad/dotfiles.git ~/github/dotfiles
cd ~/github/dotfiles
make backup          # safe — does nothing if there's nothing to back up
make init            # installs brew/apt packages from extra/homebrew or extra/apt
make osx             # macOS: symlinks configs into ~ and copies karabiner
# OR
make linux           # Linux: symlinks configs into ~
```

Open a new terminal and you should be in business.

### I'm on a computer that already has dotfiles, and I want the latest changes

```bash
cd ~/github/dotfiles
git pull
make osx             # or `make linux`
```

> `make osx` / `make linux` re-run `stow --restow`, which is safe to run repeatedly. It just refreshes the symlinks.

If I added new packages to the Brewfile or `apt/packages.txt`, also run:

```bash
make init            # installs anything new
```

### I changed a config on this computer and want it on the others

1. Edit the file **inside** `~/github/dotfiles/` (NOT the symlink target in `~`).
   - Most `~/.foo` files are already symlinks pointing into this repo, so editing `~/.zshrc` actually edits `universal/.zshrc`. That's fine.
   - The Karabiner config is the exception (it's copied, not symlinked). See "Karabiner" below.
2. Commit and push:
   ```bash
   cd ~/github/dotfiles
   git add -A
   git commit -m "describe the change"
   git push
   ```
3. On the other computer: `git pull && make osx` (or `make linux`).

---

## What lives where

```
dotfiles/
  universal/   # Cross-platform configs — symlinked to ~ via stow
  osx/         # macOS-only configs — symlinked to ~ via stow
  extra/       # NOT symlinked — used by Makefile targets
    homebrew/  # Brewfile (macOS packages)
    apt/       # packages.txt (Linux packages)
    karabiner/ # Copied to ~/.config/karabiner because the app overwrites symlinks
    dev.sh.sample  # Template for per-project .dev.sh files (used by the `dev` shell command)
```

The directory layout inside `universal/` and `osx/` mirrors `$HOME`. So `universal/.config/zsh/aliases` ends up at `~/.config/zsh/aliases`.

---

## Adding a new dotfile

1. Drop the file into `universal/` (or `osx/`) at the path it should have under `$HOME`.
   - Example: a new `~/.config/foo/bar.toml` goes in `universal/.config/foo/bar.toml`.
2. Add it to `BACKUP_TARGETS` in the `Makefile` so it gets backed up on fresh installs.
3. Run `make osx` (or `make linux`) — stow creates the symlink.
4. Commit and push.

If the app rewrites its config file on launch (and would clobber a symlink), put it in `extra/` and add a copy step to the Makefile — that's why Karabiner lives there.

---

## Adding a new package

- **macOS**: edit `extra/homebrew/Brewfile`, then `make init` (or `brew bundle --file=extra/homebrew/Brewfile`).
- **Linux**: edit `extra/apt/packages.txt`, then `make init`.

---

## Machine-specific stuff that shouldn't be in the repo

If a config is specific to one machine (work laptop vs. personal, different paths, secrets, etc.):

- For zsh: put it in `~/.zshrc.local`. The main `.zshrc` sources it automatically if it exists.
- For anything else: keep it out of the repo, or add the path to `.gitignore`.

---

## Karabiner

Karabiner-Elements overwrites its config file on launch, which breaks symlinks. So instead of stow:

- The source of truth is `extra/karabiner/karabiner.json`.
- `make osx` copies it to `~/.config/karabiner/karabiner.json`.
- **If I change Karabiner settings via the GUI**, the GUI writes to `~/.config/karabiner/karabiner.json`. To save those changes:
  ```bash
  cp ~/.config/karabiner/karabiner.json ~/github/dotfiles/extra/karabiner/karabiner.json
  cd ~/github/dotfiles && git add -A && git commit -m "karabiner: ..." && git push
  ```

---

## `make backup`

`make backup` copies every file listed in `BACKUP_TARGETS` to `~/dotfiles-backup/<timestamp>/` **only if** the file exists and is **not already a symlink**. Run it once on a new machine before `make osx` to preserve any pre-existing configs. It's safe to skip on machines that already use these dotfiles (everything is already a symlink).

---

## Tools expected on the system

- **macOS**: `brew`, `stow`, `tmux`, `starship`, `wezterm`, `aerospace`, `hammerspoon`, `karabiner-elements`, `borders`, `lazygit`, `lsd`, `ripgrep`, `nvm`, `pyenv`
- **Linux**: `stow`, `tmux`, `starship`, `lazygit`, `lsd`, `ripgrep`

`make init` installs most of these via Brewfile / `apt`.

---

## Quick reference

| I want to...                                   | Run                                  |
| ---------------------------------------------- | ------------------------------------ |
| Set up a brand new machine                     | `make backup && make init && make osx` |
| Pull latest changes from another machine       | `git pull && make osx`               |
| Re-link configs after editing files in the repo | `make osx`                           |
| Install new brew/apt packages I just added     | `make init`                          |
| Save a Karabiner GUI change back to the repo   | See "Karabiner" above                |
