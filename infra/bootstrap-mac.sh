#!/usr/bin/env bash
set -euo pipefail

# macOS bootstrap: installs Homebrew packages and configures shell
# Equivalent of bootstrap.sh for macOS — User Environment layer only
# Safe to re-run (idempotent)

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SCRIPT_VERSION="2026-02-21-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

CURRENT_PHASE="initialization"

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
log_fatal() { printf "${RED}[FATAL]${NC} %s\n" "$1" >&2; }

die() {
	log_fatal "$1"
	log_fatal "Phase: ${CURRENT_PHASE}"
	log_fatal "Bootstrap did NOT complete. Fix the error above and re-run."
	exit 1
}

on_error() {
	local line="$1"
	local cmd="$2"
	local code="$3"
	echo "" >&2
	printf "%s╔══════════════════════════════════════════════════════════════════╗%s\n" "${RED}${BOLD}" "${NC}" >&2
	printf "%s║                   macOS BOOTSTRAP FAILED                         ║%s\n" "${RED}${BOLD}" "${NC}" >&2
	printf "%s╚══════════════════════════════════════════════════════════════════╝%s\n" "${RED}${BOLD}" "${NC}" >&2
	echo "" >&2
	log_fatal "Phase: ${CURRENT_PHASE}"
	log_fatal "Exit code: ${code}"
	log_fatal "Line ${line}: ${cmd}"
	echo "" >&2
	log_fatal "Bootstrap did NOT complete successfully."
	log_fatal "To retry: ./infra/bootstrap-mac.sh"
}

trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

check_prerequisites() {
	log_info "Running pre-flight checks..."

	if [[ "$(uname)" != "Darwin" ]]; then
		die "This script must run on macOS (detected: $(uname))"
	fi

	# Check network connectivity
	if ! ping -c 1 -W 5 github.com >/dev/null 2>&1; then
		die "No network connectivity — check your internet connection"
	fi

	log_info "Pre-flight checks passed"
}

# =============================================================================
# HOMEBREW
# =============================================================================

install_homebrew() {
	if command -v brew >/dev/null 2>&1; then
		log_info "Homebrew already installed"
		return 0
	fi

	log_info "Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	# Ensure brew is on PATH for the rest of this script
	if [[ -f /opt/homebrew/bin/brew ]]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [[ -f /usr/local/bin/brew ]]; then
		eval "$(/usr/local/bin/brew shellenv)"
	fi

	log_info "Homebrew installed successfully"
}

# =============================================================================
# PACKAGE INSTALLATION
# =============================================================================

install_brew_formulae() {
	local pkg_file="${SCRIPT_DIR}/pkgs.brew.txt"

	if [[ ! -f "$pkg_file" ]]; then
		log_warn "No Homebrew formulae list found at $pkg_file"
		return 0
	fi

	local packages=()
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// /}" ]] && continue
		packages+=("$line")
	done <"$pkg_file"

	if [[ ${#packages[@]} -eq 0 ]]; then
		log_info "No Homebrew formulae to install"
		return 0
	fi

	log_info "Installing ${#packages[@]} Homebrew formulae..."
	brew install "${packages[@]}"
}

install_brew_casks() {
	local pkg_file="${SCRIPT_DIR}/pkgs.brew-cask.txt"

	if [[ ! -f "$pkg_file" ]]; then
		log_warn "No Homebrew cask list found at $pkg_file"
		return 0
	fi

	local casks=()
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// /}" ]] && continue
		casks+=("$line")
	done <"$pkg_file"

	if [[ ${#casks[@]} -eq 0 ]]; then
		log_info "No Homebrew casks to install"
		return 0
	fi

	log_info "Installing ${#casks[@]} Homebrew casks..."
	brew install --cask "${casks[@]}"
}

# =============================================================================
# ZATHURA (PDF viewer with SyncTeX support)
# =============================================================================

install_zathura() {
	log_info "Setting up zathura..."

	# Tap the homebrew-zathura repository (maintained by zegervdv)
	if ! brew tap | grep -q "^zegervdv/zathura$"; then
		log_info "Tapping zegervdv/zathura..."
		brew tap zegervdv/zathura
	else
		log_info "zegervdv/zathura tap already present"
	fi

	# Install zathura and the MuPDF plugin
	brew install zathura
	brew install zathura-pdf-mupdf

	# Post-install: symlink the plugin into zathura's lib directory
	# Without this, zathura cannot find its PDF rendering plugin
	local zathura_lib
	zathura_lib="$(brew --prefix zathura)/lib/zathura"
	mkdir -p "$zathura_lib"

	local mupdf_plugin
	mupdf_plugin="$(brew --prefix zathura-pdf-mupdf)/libpdf-mupdf.dylib"
	if [[ -f "$mupdf_plugin" ]]; then
		if [[ ! -e "${zathura_lib}/libpdf-mupdf.dylib" ]]; then
			ln -s "$mupdf_plugin" "$zathura_lib/"
			log_info "Linked zathura-pdf-mupdf plugin"
		else
			log_info "zathura-pdf-mupdf plugin already linked"
		fi
	else
		log_warn "zathura-pdf-mupdf plugin not found at $mupdf_plugin"
	fi

	log_info "Zathura setup complete"
}

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================

set_default_shell() {
	log_info "Checking default shell..."

	if [[ "$SHELL" == */zsh ]]; then
		log_info "Default shell is already zsh"
		return 0
	fi

	local brew_zsh
	brew_zsh="$(brew --prefix)/bin/zsh"

	if [[ ! -x "$brew_zsh" ]]; then
		log_warn "Homebrew zsh not found at $brew_zsh — skipping shell change"
		return 0
	fi

	# Add Homebrew zsh to allowed shells if not already present
	if ! grep -qxF "$brew_zsh" /etc/shells 2>/dev/null; then
		log_info "Adding $brew_zsh to /etc/shells..."
		echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null
	fi

	log_info "Changing default shell to $brew_zsh..."
	chsh -s "$brew_zsh"
	log_info "Default shell changed to zsh (will take effect on next login)"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
	log_info "macOS bootstrap script version: ${SCRIPT_VERSION}"
	log_info "Starting archway macOS bootstrap..."
	log_info "Repository: $REPO_ROOT"

	CURRENT_PHASE="pre-flight checks"
	check_prerequisites

	CURRENT_PHASE="installing Homebrew"
	install_homebrew

	CURRENT_PHASE="installing Homebrew formulae"
	install_brew_formulae

	CURRENT_PHASE="installing Homebrew casks"
	install_brew_casks

	# Zathura (PDF viewer with SyncTeX) — requires third-party tap + post-install
	CURRENT_PHASE="installing zathura"
	install_zathura

	CURRENT_PHASE="setting default shell to zsh"
	set_default_shell

	CURRENT_PHASE="complete"

	local state_dir
	state_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/archway"
	mkdir -p "$state_dir"
	cat >"${state_dir}/bootstrap-mac.complete" <<EOF
BOOTSTRAP_VERSION="${SCRIPT_VERSION}"
BOOTSTRAP_COMPLETED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPO_ROOT="${REPO_ROOT}"
EOF

	log_info ""
	log_info "=========================================="
	log_info "macOS bootstrap complete!"
	log_info "=========================================="
	log_info ""
	log_info "Next steps:"
	log_info "  1. Apply dotfiles: ./infra/dotfiles.sh"
	log_info "  2. Restart your terminal"
	log_info "  3. Oh-my-zsh and plugins will auto-install on first shell start"
}

main "$@"
