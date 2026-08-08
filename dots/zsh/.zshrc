# ~/.zshrc - managed by archway
# Self-bootstrapping zsh configuration

# =============================================================================
# HOMEBREW (macOS)
# =============================================================================
# Ensure Homebrew is in PATH before anything else
if [[ "$(uname)" == "Darwin" ]]; then
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# =============================================================================
# OH-MY-ZSH SETUP
# =============================================================================
# Oh-my-zsh and its plugins are installed by `just dotfiles` (see
# infra/dotfiles.sh :: install_oh_my_zsh). We do NOT clone them lazily here:
# that approach silently failed on fresh installs when the very first shell
# launched before network/git were ready, leaving the user with a broken
# shell. If you see the error below on a fresh machine, run:
#     just dotfiles
export ZSH="${HOME}/.oh-my-zsh"

if [[ ! -f "$ZSH/oh-my-zsh.sh" ]]; then
    print -ru2 -- "[zshrc] oh-my-zsh not found at $ZSH"
    print -ru2 -- "[zshrc] Run: just dotfiles    (from your archway repo)"
    print -ru2 -- "[zshrc] Skipping oh-my-zsh load; prompt + plugins will be unavailable."
    return 0
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

# Oh-my-zsh configuration
plugins=(
    git
    sudo
    command-not-found
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf-tab
)

# Theme (custom minimal prompt)
ZSH_THEME="afowler" # set by `omz`

# Load oh-my-zsh
source "$ZSH/oh-my-zsh.sh"

# # Custom prompt - minimal with user@host
# # %F{117} = pastel cyan, %F{green} = green path, %F{red} = red error
# PROMPT='%F{117}%n@%m%f %F{green}%~%f $(git_prompt_info)%(?,%F{red}✗%f ,)'

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

# FZF
if command -v fzf &>/dev/null; then
    # Source fzf keybindings (path differs by platform)
    if [[ "$(uname)" == "Darwin" ]]; then
        local brew_prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
        [[ -f "${brew_prefix}/opt/fzf/shell/key-bindings.zsh" ]] && source "${brew_prefix}/opt/fzf/shell/key-bindings.zsh"
        [[ -f "${brew_prefix}/opt/fzf/shell/completion.zsh" ]] && source "${brew_prefix}/opt/fzf/shell/completion.zsh"
    else
        [[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
        [[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
    fi
    
    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    
    zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border
    zstyle ':fzf-tab:*' switch-group ',' '.'
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
    zstyle ':fzf-tab:complete:z:*' fzf-preview 'eza -1 --color=always $realpath'
fi

# Zoxide (smart cd)
# Initialized AFTER fzf to ensure interactive mode (zi) picks up fzf config
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# Starship prompt (disabled - using default zsh prompt)
# if command -v starship &>/dev/null; then
#     eval "$(starship init zsh)"
# fi

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
# ALIASES - Lazygit
# =============================================================================
if command -v lazygit &>/dev/null; then
    alias lg='lazygit'
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
# TMUX - Session management
# =============================================================================
if command -v tmux &>/dev/null; then
    # x [dir] - sessionizer: create or attach to a tmux session for a project dir.
    # With no arg, opens an fzf picker (also used as the completion backend).
    # Set SESSIONIZER_DIRS (colon-separated) to control which dirs are searched.
    #   export SESSIONIZER_DIRS="$HOME/projects:$HOME/work"
    x() {
        ~/bin/tmux-sessionizer "${1:-}"
    }

    # xa [session] - attach to an existing session (fzf picker if no arg)
    xa() {
        if [[ -n "${1:-}" ]]; then
            tmux attach-session -t "$1"
        else
            local session
            session=$(tmux list-sessions -F '#S' 2>/dev/null | fzf --prompt='attach: ' --height=40% --layout=reverse --border) \
                && tmux attach-session -t "$session"
        fi
    }

    # xn [name] - new session named after arg or current directory
    xn() {
        local name="${1:-$(basename "$PWD")}"
        tmux new-session -s "${name//\./_}"
    }

    # xl - list sessions
    alias xl='tmux ls'

    # ── Completions ────────────────────────────────────────────────────────────

    # x: complete with zoxide history (same source as `zi`)
    _x_complete() {
        local -a dirs
        if command -v zoxide &>/dev/null; then
            dirs=( ${(f)"$(zoxide query --list 2>/dev/null)"} )
        fi
        _wanted directories expl 'project directory' compadd -a dirs
    }
    compdef _x_complete x

    # xa: complete with existing tmux session names
    _xa_complete() {
        local -a sessions
        sessions=( ${(f)"$(tmux list-sessions -F '#S' 2>/dev/null)"} )
        _wanted sessions expl 'tmux session' compadd -a sessions
    }
    compdef _xa_complete xa

    # fzf-tab preview for x: show dir contents
    zstyle ':fzf-tab:complete:x:*' fzf-preview 'eza -1 --color=always $realpath 2>/dev/null'
fi

# =============================================================================
# ALIASES - System
# =============================================================================
if [[ "$(uname)" == "Darwin" ]]; then
    alias update='brew update && brew upgrade'
else
    alias update='sudo pacman -Syu'
fi
alias please='sudo'
alias df='df -h'

# Quick config edits
alias zshconfig='${EDITOR:-nvim} ~/.zshrc'
if [[ "$(uname)" != "Darwin" ]]; then
    alias hyprconfig='${EDITOR:-nvim} ~/.config/hypr/hyprland.conf'
fi

# =============================================================================
# ALIASES - Calendar (khal)
# =============================================================================
if command -v khal &>/dev/null; then
    alias kday='khal list today today'
    alias kweek='khal list today 7d'
    alias kmonth='khal calendar'
    alias kcal='khal interactive'
fi

# =============================================================================
# ALIASES - Archway helpers
# =============================================================================
if [[ "$(uname)" == "Darwin" ]]; then
    alias archway-sync='cd ~/archway && ./infra/bootstrap-mac.sh && ./infra/dotfiles.sh'
else
    alias archway-sync='cd ~/archway && ./infra/bootstrap.sh && ./infra/dotfiles.sh && ./infra/doctor.sh'
    alias archway-doctor='~/archway/infra/doctor.sh'
    alias archway-audit='~/archway/infra/doctor.sh --audit-packages'
fi

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


# =============================================================================
# LOGIN BANNER
# =============================================================================
# Show the configured system summary when an interactive terminal opens.
if [[ -o interactive ]] && command -v fastfetch &>/dev/null; then
    command fastfetch
fi

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
