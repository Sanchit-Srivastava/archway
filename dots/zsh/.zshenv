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
# PLATFORM-SPECIFIC
# =============================================================================
if [[ "$(uname)" != "Darwin" ]]; then
    # Wayland (Linux only)
    export MOZ_ENABLE_WAYLAND=1
    export QT_QPA_PLATFORM=wayland
    export SDL_VIDEODRIVER=wayland
fi

# =============================================================================
# SSH AGENT (Bitwarden)
# =============================================================================
# The Bitwarden desktop app provides an SSH agent.
# Enable in: Bitwarden Desktop > Settings > SSH Agent
#
# Socket location varies by platform and install method:
#   Linux (pacman/AUR):       ~/.bitwarden-ssh-agent.sock
#   macOS (.dmg / Homebrew):  ~/.bitwarden-ssh-agent.sock
#   macOS (App Store):        ~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock
#
# When connected via SSH with agent forwarding, SSH_AUTH_SOCK is already set
# by sshd to the forwarded socket — don't override it.
if [[ -z "$SSH_CONNECTION" ]]; then
    # Local session: use the Bitwarden socket
    if [[ "$(uname)" == "Darwin" ]]; then
        _bw_mas="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
        _bw_dmg="$HOME/.bitwarden-ssh-agent.sock"
        if [[ -S "$_bw_mas" ]]; then
            export SSH_AUTH_SOCK="$_bw_mas"
        elif [[ -S "$_bw_dmg" ]]; then
            export SSH_AUTH_SOCK="$_bw_dmg"
        else
            # Neither socket exists yet (Bitwarden not running); default to App Store path
            export SSH_AUTH_SOCK="$_bw_mas"
        fi
        unset _bw_mas _bw_dmg
    else
        export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
    fi
fi

# =============================================================================
# XDG BASE DIRECTORIES
# =============================================================================
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
