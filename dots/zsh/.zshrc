# ~/.zshrc - managed by archway
# Self-bootstrapping zsh configuration

# =============================================================================
# OH-MY-ZSH SETUP (auto-install if missing)
# =============================================================================
export ZSH="${HOME}/.oh-my-zsh"

if [[ ! -d "$ZSH" ]]; then
    echo "Installing oh-my-zsh..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH"
fi

# Plugins (auto-install if missing)
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    echo "Installing zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    echo "Installing zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Oh-my-zsh configuration
plugins=(
    git
    sudo
    command-not-found
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Theme (overridden by starship)
ZSH_THEME="robbyrussell"

# Load oh-my-zsh
source "$ZSH/oh-my-zsh.sh"

# =============================================================================
# HISTORY
# =============================================================================
HISTFILE="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/history"
HISTSIZE=100000
SAVEHIST=100000

# Create history directory if needed
[[ -d "$(dirname "$HISTFILE")" ]] || mkdir -p "$(dirname "$HISTFILE")"

setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_SPACE

# =============================================================================
# TOOL INTEGRATIONS
# =============================================================================

# Starship prompt (disabled - using default zsh prompt)
# if command -v starship &>/dev/null; then
#     eval "$(starship init zsh)"
# fi

# Zoxide (smart cd)
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# FZF
if command -v fzf &>/dev/null; then
    # Try to source fzf keybindings
    [[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
    [[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
    
    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Yazi (terminal file browser) - change cwd on exit
if command -v yazi &>/dev/null; then
    function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        command yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d '' cwd < "$tmp"
        [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
        rm -f -- "$tmp"
    }
fi

# =============================================================================
# ALIASES - Modern replacements
# =============================================================================

# Better cat
if command -v bat &>/dev/null; then
    alias cat='bat --style=plain'
fi

# Better ls
if command -v eza &>/dev/null; then
    alias ls='eza --group-directories-first --icons'
    alias ll='eza -la --group-directories-first --icons'
    alias la='eza -a --group-directories-first --icons'
    alias lt='eza --tree --level=2 --icons'
fi

# Better grep
if command -v rg &>/dev/null; then
    alias grep='rg'
fi

# Better find
if command -v fd &>/dev/null; then
    alias find='fd'
fi

# Better du
if command -v dust &>/dev/null; then
    alias du='dust'
fi

# =============================================================================
# ALIASES - Git shortcuts
# =============================================================================
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gcb='git checkout -b'
alias glog='git log --oneline --graph --decorate'

# =============================================================================
# ALIASES - Navigation
# =============================================================================
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# =============================================================================
# ALIASES - System
# =============================================================================
alias update='sudo pacman -Syu'
alias please='sudo'
alias df='df -h'

# Quick config edits
alias zshconfig='${EDITOR:-nvim} ~/.zshrc'
alias hyprconfig='${EDITOR:-nvim} ~/.config/hypr/hyprland.conf'

# =============================================================================
# ALIASES - Archway helpers
# =============================================================================
alias archway-sync='cd ~/archway && ./infra/bootstrap.sh && ./infra/dotfiles.sh && ./infra/doctor.sh'
alias archway-doctor='~/archway/infra/doctor.sh'
alias archway-audit='~/archway/infra/doctor.sh --audit-packages'

# =============================================================================
# COMPLETION
# =============================================================================
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# =============================================================================
# LOCAL OVERRIDES
# =============================================================================
# Source local config if it exists (for machine-specific settings)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
