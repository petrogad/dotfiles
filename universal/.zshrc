# -- Plugin manager (znap) -----------------------------------------------------

[[ -r ~/.config/zsh/znap ]] ||
    git clone --depth 1 -- https://github.com/marlonrichert/zsh-snap.git ~/.config/zsh/znap

source ~/.config/zsh/znap/znap.zsh

# oh-my-zsh core + git plugin
znap source ohmyzsh/ohmyzsh
znap source ohmyzsh/ohmyzsh plugins/git

# -- History -------------------------------------------------------------------

unsetopt share_history
setopt inc_append_history

# -- Plugins -------------------------------------------------------------------

ZSH_AUTOSUGGEST_STRATEGY=( history )
znap source zsh-users/zsh-autosuggestions

ZSH_HIGHLIGHT_HIGHLIGHTERS=( main brackets )
znap source zsh-users/zsh-syntax-highlighting

# -- NVM -----------------------------------------------------------------------

export NVM_DIR="$HOME/.nvm"
export NVM_SYMLINK_CURRENT=true
export NVM_AUTO_USE=true
export NVM_LAZY_LOAD=true

# -- pyenv ---------------------------------------------------------------------

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv &>/dev/null && eval "$(pyenv init - zsh)"

# -- ripgrep -------------------------------------------------------------------

export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"

# -- Platform-specific ---------------------------------------------------------

case $(uname) in
    Darwin)
        export PATH="$PATH:$HOME/.nvm/current/bin"
        export PATH="$PATH:$HOME/.local/bin"
        export PATH="$PATH:$HOME/.dotnet/tools"

        # pnpm
        export PNPM_HOME="$HOME/Library/pnpm"
        case ":$PATH:" in
            *":$PNPM_HOME:"*) ;;
            *) export PATH="$PNPM_HOME:$PATH" ;;
        esac

        # WezTerm CLI
        export PATH="$PATH:/Applications/WezTerm.app/Contents/MacOS"

        # nvm (homebrew)
        [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
    ;;
    Linux)
        export TERM=xterm-256color
        export EDITOR="vim"
        export GIT_SSH=/usr/bin/ssh
        export PATH="$PATH:$HOME/.local/bin"
    ;;
esac

# -- Modular configs -----------------------------------------------------------

[ -f ~/.config/zsh/aliases ] && . ~/.config/zsh/aliases
[ -f ~/.config/zsh/git ]     && . ~/.config/zsh/git
[ -f ~/.config/zsh/tmux ]    && . ~/.config/zsh/tmux
[ -f ~/.config/zsh/agents ]  && . ~/.config/zsh/agents

# -- Local overrides (not tracked in dotfiles) ---------------------------------

[ -f ~/.local/bin/env ] && . ~/.local/bin/env
[ -f ~/.zshrc.local ]   && . ~/.zshrc.local

# -- Prompt (starship) ---------------------------------------------------------

znap eval starship 'starship init zsh'
znap prompt

# -- Completions ---------------------------------------------------------------

fpath=(~/.config/zsh/completions $fpath)
