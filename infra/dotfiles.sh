#!/usr/bin/env bash
set -euo pipefail

# Dotfiles installer: symlinks user dotfiles from dots/ to ~
# Safe to re-run (idempotent)

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOTS_DIR="${REPO_ROOT}/dots"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

# Link a dotfile or directory
# Usage: link_dotfile <source> <destination>
link_dotfile() {
	local src="$1"
	local dst="$2"

	# Ensure parent directory exists
	mkdir -p "$(dirname "$dst")"

	if [[ -L "$dst" ]]; then
		local current_target
		current_target="$(readlink "$dst")"
		if [[ "$current_target" == "$src" ]]; then
			log_info "Already linked: $dst"
			return 0
		fi
		log_warn "Removing old symlink: $dst -> $current_target"
		rm "$dst"
	elif [[ -e "$dst" ]]; then
		log_warn "Backing up existing: $dst -> ${dst}.bak"
		mv "$dst" "${dst}.bak"
	fi

	ln -s "$src" "$dst"
	log_info "Linked: $dst -> $src"
}

# Main dotfile linking
main() {
	log_info "Installing dotfiles from ${DOTS_DIR}"
	log_info ""

	# Verify dots directory exists
	if [[ ! -d "$DOTS_DIR" ]]; then
		log_error "Dots directory not found: $DOTS_DIR"
		exit 1
	fi

	# ==========================================================================
	# ZSH
	# ==========================================================================
	log_info "--- Zsh ---"
	link_dotfile "${DOTS_DIR}/zsh/.zshrc" "${HOME}/.zshrc"
	link_dotfile "${DOTS_DIR}/zsh/.zshenv" "${HOME}/.zshenv"

	# ==========================================================================
	# STARSHIP
	# ==========================================================================
	log_info "--- Starship ---"
	link_dotfile "${DOTS_DIR}/starship/starship.toml" "${HOME}/.config/starship.toml"

	# ==========================================================================
	# TMUX
	# ==========================================================================
	log_info "--- Tmux ---"
	mkdir -p "${HOME}/.config/tmux"
	link_dotfile "${DOTS_DIR}/tmux/tmux.conf" "${HOME}/.config/tmux/tmux.conf"

	# ==========================================================================
	# NEOVIM
	# ==========================================================================
	log_info "--- Neovim ---"
	link_dotfile "${DOTS_DIR}/nvim" "${HOME}/.config/nvim"

	# ==========================================================================
	# GIT
	# ==========================================================================
	log_info "--- Git ---"
	link_dotfile "${DOTS_DIR}/git/.gitconfig" "${HOME}/.gitconfig"

	# ==========================================================================
	# SSH
	# ==========================================================================
	log_info "--- SSH ---"
	mkdir -p "${HOME}/.ssh/sockets"
	chmod 700 "${HOME}/.ssh"
	link_dotfile "${DOTS_DIR}/ssh/config" "${HOME}/.ssh/config"
	chmod 600 "${HOME}/.ssh/config" 2>/dev/null || true

	# ==========================================================================
	# ZATHURA (PDF viewer with SyncTeX support)
	# ==========================================================================
	log_info "--- Zathura ---"
	mkdir -p "${HOME}/.config/zathura"
	link_dotfile "${DOTS_DIR}/zathura/zathurarc" "${HOME}/.config/zathura/zathurarc"

	# ==========================================================================
	# FASTFETCH
	# ==========================================================================
	log_info "--- Fastfetch ---"
	link_dotfile "${DOTS_DIR}/fastfetch/config.jsonc" "${HOME}/.config/fastfetch/config.jsonc"

	# ==========================================================================
	# BAT (theme config)
	# ==========================================================================
	log_info "--- Bat ---"
	mkdir -p "${HOME}/.config/bat"
	if [[ ! -f "${HOME}/.config/bat/config" ]]; then
		cat >"${HOME}/.config/bat/config" <<'EOF'
--theme="TwoDark"
--pager="less -FR"
EOF
		log_info "Created bat config"
	else
		log_info "Bat config already exists"
	fi

	# ==========================================================================
	# GITHUB CLI
	# ==========================================================================
	log_info "--- GitHub CLI ---"
	mkdir -p "${HOME}/.config/gh"
	if [[ ! -f "${HOME}/.config/gh/config.yml" ]]; then
		cat >"${HOME}/.config/gh/config.yml" <<'EOF'
git_protocol: ssh
editor: nvim
EOF
		log_info "Created gh config"
	else
		log_info "GitHub CLI config already exists"
	fi

	# ==========================================================================
	# LINUX-ONLY SECTIONS
	# ==========================================================================
	if [[ "$(uname)" != "Darwin" ]]; then
		# ==========================================================================
		# ENVIRONMENT.D (systemd user session environment)
		# ==========================================================================
		log_info "--- Environment.d ---"
		mkdir -p "${HOME}/.config/environment.d"
		link_dotfile "${DOTS_DIR}/environment.d/50-archway.conf" "${HOME}/.config/environment.d/50-archway.conf"

		# ==========================================================================
		# LOCAL BIN
		# ==========================================================================
		log_info "--- Local bin ---"
		mkdir -p "${HOME}/.local/bin"
		if [[ -f "${REPO_ROOT}/bin/archway-install" ]]; then
			chmod +x "${REPO_ROOT}/bin/archway-install"
			ln -sf "${REPO_ROOT}/bin/archway-install" "${HOME}/.local/bin/archway-install"
			log_info "Linked: ${HOME}/.local/bin/archway-install"
		else
			log_warn "archway-install wrapper not found, skipping"
		fi
	fi

	log_info ""
	log_info "=========================================="
	log_info "Dotfiles installation complete!"
	log_info "=========================================="
	log_info ""
	log_info "Notes:"
	log_info "  - Restart your shell or run: source ~/.zshrc"
	log_info "  - Oh-my-zsh and plugins will auto-install on first shell start"
	log_info "  - Edit dots/git/.gitconfig to set your name and email"
	log_info "  - Edit dots/ssh/config to add your SSH hosts"
}

main "$@"
