# $EDITOR — what anything that shells out to "an editor" opens.
#
# Exported rather than set so it survives into subprocesses: git commit, `agent-mgr
# note edit`, and anything else that shells out reads it from the environment. Set
# here in env.d rather than in .zshrc proper so it is one thing in one file.
#
# VISUAL as well as EDITOR because the convention is that VISUAL wins for a
# full-screen editor and EDITOR is the line-mode fallback; tools disagree about
# which they read, and a machine where they name different editors is a machine
# where you cannot predict what a keypress opens.
# GNU nano, not the UW PICO clone macOS ships as /usr/bin/nano — pico has no
# syntax highlighting and no nanorc at all. Homebrew's bin precedes /usr/bin on
# PATH, so the name resolves to the right one; left unqualified rather than
# absolute so this file is also correct on an Intel mac and on Linux.
export EDITOR=nano
export VISUAL=nano
