# Rust from rustup, never the distro's.
#
# Debian 13 ships rustc 1.85, and tmux-agent-mgr's own dependencies already
# require 1.88. The plugin builds itself on first load, so on a distro
# toolchain that build fails, no binary appears, and the sidebar simply never
# opens — which looks like tmux hanging rather than a compile error.
#
# PREPENDED, so rustup's cargo beats /usr/bin/cargo when both exist.
[[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:$PATH"
