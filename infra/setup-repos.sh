#!/usr/bin/env bash
set -eEuo pipefail

# setup-repos.sh: idempotently configure third-party pacman repositories
#
# Adds:
#   - CachyOS repos (cachyos, cachyos-v3, cachyos-v4 if CPU supports)
#       Provides: linux-cachyos, cachyos-settings, chwd, proton-cachyos,
#       cachyos-gaming-meta, and v3/v4-optimized rebuilds of common packages.
#   - Chaotic-AUR repo
#       Pre-built AUR binaries (proton-ge-custom, nvidia-open-dkms, etc.)
#
# Also enables [multilib] (needed for 32-bit Steam/Wine on NVIDIA).
#
# This script is idempotent: safe to re-run.

SCRIPT_VERSION="2026-05-03-1"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

die() {
	log_error "$1"
	exit 1
}

PACMAN_CONF="/etc/pacman.conf"

require_arch() {
	if [[ ! -f /etc/arch-release ]]; then
		die "This script must run on Arch Linux"
	fi
}

# -----------------------------------------------------------------------------
# Multilib
# -----------------------------------------------------------------------------
enable_multilib() {
	if pacman-conf --repo=multilib >/dev/null 2>&1; then
		log_info "multilib repo already enabled"
		return 0
	fi

	log_info "Enabling [multilib] repo in ${PACMAN_CONF}"
	# Uncomment the [multilib] section (header + Include line that follows).
	sudo sed -i '/^\s*#\s*\[multilib\]/{
		s/^\s*#\s*//
		n
		s/^\s*#\s*//
	}' "$PACMAN_CONF"

	if ! pacman-conf --repo=multilib >/dev/null 2>&1; then
		die "Failed to enable [multilib] in ${PACMAN_CONF} - inspect manually"
	fi
}

# -----------------------------------------------------------------------------
# CachyOS repo
# -----------------------------------------------------------------------------
# We use the official cachyos-repo installer script. It detects CPU level
# (x86-64-v3 / v4) and writes the correct repo entries + installs the keyring.
# Re-running it is a no-op (it checks for existing entries).
setup_cachyos_repo() {
	if pacman-conf --repo=cachyos >/dev/null 2>&1; then
		log_info "CachyOS repo already configured"
		return 0
	fi

	log_info "Installing CachyOS repo (downloads installer from cachyos.org)..."

	local tmpdir
	tmpdir=$(mktemp -d)
	trap 'rm -rf "$tmpdir"' RETURN

	# Official installer tarball pinned by name (URL stable since 2023)
	local url="https://mirror.cachyos.org/cachyos-repo.tar.xz"

	if ! curl -fsSL --retry 3 -o "${tmpdir}/cachyos-repo.tar.xz" "$url"; then
		die "Failed to download CachyOS repo installer from $url"
	fi

	tar -xf "${tmpdir}/cachyos-repo.tar.xz" -C "$tmpdir"

	# The installer is interactive-friendly but accepts running non-interactively.
	# It installs the keyring, mirrorlist, and adds repo entries to pacman.conf.
	if ! sudo bash "${tmpdir}/cachyos-repo/cachyos-repo.sh"; then
		die "CachyOS repo installer failed - inspect output above"
	fi

	if ! pacman-conf --repo=cachyos >/dev/null 2>&1; then
		die "CachyOS repo not present after installer ran"
	fi

	log_info "CachyOS repo installed"
}

# -----------------------------------------------------------------------------
# Chaotic-AUR repo
# -----------------------------------------------------------------------------
# https://aur.chaotic.cx/
setup_chaotic_aur() {
	if pacman-conf --repo=chaotic-aur >/dev/null 2>&1; then
		log_info "chaotic-aur repo already configured"
		return 0
	fi

	log_info "Installing chaotic-aur key and mirrorlist..."

	# Receive and locally sign the chaotic key
	sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
	sudo pacman-key --lsign-key 3056513887B78AEB

	# Install keyring + mirrorlist packages from the chaotic CDN
	sudo pacman -U --noconfirm \
		'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
		'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

	# Append repo block to pacman.conf if not already there
	if ! grep -q '^\[chaotic-aur\]' "$PACMAN_CONF"; then
		log_info "Appending [chaotic-aur] to ${PACMAN_CONF}"
		sudo tee -a "$PACMAN_CONF" >/dev/null <<'EOF'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
	fi

	if ! pacman-conf --repo=chaotic-aur >/dev/null 2>&1; then
		die "chaotic-aur repo not active after setup"
	fi

	log_info "chaotic-aur repo installed"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	log_info "setup-repos.sh version: ${SCRIPT_VERSION}"
	require_arch

	enable_multilib
	setup_cachyos_repo
	setup_chaotic_aur

	log_info "Refreshing pacman databases..."
	sudo pacman -Sy

	log_info "Repository setup complete"
	log_info "Available extras now installable:"
	log_info "  - linux-cachyos          (optimized kernel)"
	log_info "  - cachyos-settings       (perf tweaks; in pkgs.pacman.txt)"
	log_info "  - chwd                   (hardware detection; in pkgs.pacman.txt)"
	log_info "  - cachyos-gaming-meta    (gaming bundle - opt-in)"
	log_info "  - proton-cachyos         (optimized Proton)"
	log_info "  - proton-ge-custom-bin   (via chaotic-aur)"
	log_info "See docs/GAMING.md for the full list."
}

main "$@"
