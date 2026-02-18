# ~/.zshenv - environment variables (loaded for all shells)
# managed by archway

# =============================================================================
# EDITOR
# =============================================================================
export EDITOR="nvim"
export VISUAL="nvim"

# =============================================================================
# PATH
# =============================================================================
export PATH="$HOME/.local/bin:$PATH"

# =============================================================================
# WAYLAND
# =============================================================================
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland

# =============================================================================
# SSH AGENT (Bitwarden)
# =============================================================================
# The Bitwarden desktop app provides an SSH agent at this socket
# Enable in: Bitwarden Desktop > Settings > SSH Agent
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"

# =============================================================================
# XDG BASE DIRECTORIES
# =============================================================================
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
