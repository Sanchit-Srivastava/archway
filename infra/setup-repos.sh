#!/usr/bin/env bash
set -eEuo pipefail

# setup-repos.sh: idempotently configure OPT-IN third-party pacman repositories
#
# This script is NOT called by bootstrap.sh. It is opt-in. Run it manually
# (or via `just setup-repos`) when you want CachyOS / chaotic-aur packages.
# Multilib is enabled directly by bootstrap.sh.
#
# Adds:
#   - CachyOS repos (cachyos, cachyos-v3, cachyos-v4 if CPU supports)
#       Provides: linux-cachyos, cachyos-settings, chwd, proton-cachyos,
#       cachyos-gaming-meta, and v3/v4-optimized rebuilds of common packages.
#   - Chaotic-AUR repo
#       Pre-built AUR binaries (proton-ge-custom, nvidia-open-dkms, etc.)
#
# Also re-asserts [multilib] is enabled (bootstrap.sh already does this, but
# this script remains usable on systems that skipped bootstrap).
#
# This script is idempotent: safe to re-run.

SCRIPT_VERSION="2026-05-07-1"

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

# log_* + colors from lib/common.sh
die() {
	log_error "$1"
	exit 1
}

# fail: like die, but for use inside per-repo functions invoked from main
# with `|| failed+=(...)`. Returns non-zero rather than exiting so other
# repos still get a chance to be configured.
fail() {
	log_error "$1"
	return 1
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
		fail "Failed to enable [multilib] in ${PACMAN_CONF} - inspect manually"
		return 1
	fi
}

# -----------------------------------------------------------------------------
# CachyOS repo
# -----------------------------------------------------------------------------
# We use the official cachyos-repo installer script. It detects CPU level
# (x86-64-v3 / v4) and writes the correct repo entries + installs the keyring.
# Re-running it is a no-op (it checks for existing entries).
setup_cachyos_repo() {
	# Cheap check first: did a previous run already add the repo block?
	# We grep pacman.conf directly rather than calling `pacman-conf --repo=cachyos`
	# because pacman-conf can fail for unrelated reasons (missing mirrorlist
	# file mid-install, syntax error elsewhere) and would give a misleading
	# negative.
	if grep -qE '^\[cachyos(-v[34]|-znver4)?\]' "$PACMAN_CONF"; then
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
		fail "Failed to download CachyOS repo installer from $url"
		return 1
	fi

	tar -xf "${tmpdir}/cachyos-repo.tar.xz" -C "$tmpdir"

	# The CachyOS installer unconditionally runs `pacman-key --recv-keys`
	# against keyserver.ubuntu.com over the GPG keyserver protocol (HKP).
	# In environments where HKP is blocked or flaky, this fails and the
	# installer aborts before adding the repo block to pacman.conf.
	#
	# Workaround: pre-import the key over plain HTTPS (which works), then
	# patch the installer to skip its own keyserver fetch.
	local cachyos_key="F3B607488DB35A47"
	local installer="${tmpdir}/cachyos-repo/cachyos-repo.sh"

	if ! sudo pacman-key --list-keys "$cachyos_key" >/dev/null 2>&1; then
		log_info "Pre-importing CachyOS signing key via HTTPS (keyserver fallback)..."
		local keyserver_https="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${cachyos_key}"
		if ! curl -fsSL --retry 3 "$keyserver_https" | sudo pacman-key --add -; then
			fail "Failed to fetch CachyOS signing key over HTTPS"
			return 1
		fi
		sudo pacman-key --lsign-key "$cachyos_key"
	else
		log_info "CachyOS signing key already in pacman keyring"
		# Ensure it's locally signed (idempotent — no-op if already signed)
		sudo pacman-key --lsign-key "$cachyos_key" >/dev/null 2>&1 || true
	fi

	# Patch the installer to skip its own keyserver fetch+sign — we just did
	# both above. Replace those two lines with `:` (bash no-op) so the rest
	# of the installer (keyring/mirrorlist install, repo block insertion)
	# still runs.
	sed -i \
		-e 's|^\(\s*\)pacman-key --recv-keys F3B607488DB35A47.*$|\1: # pre-imported by setup-repos.sh|' \
		-e 's|^\(\s*\)pacman-key --lsign-key F3B607488DB35A47.*$|\1: # pre-signed by setup-repos.sh|' \
		"$installer"

	# The installer adds the repo entries + installs keyring/mirrorlist.
	# It also runs `pacman -Syu` at the end (full system upgrade), which can
	# fail for unrelated reasons. We don't treat that as fatal — we only
	# care that the repo block landed in pacman.conf. The next pacman -Sy
	# in bootstrap will pick up the new repo regardless.
	#
	# IMPORTANT: the installer references its bundled awk scripts via
	# relative paths (./install-repo.awk, ./install-v4-repo.awk, etc.) and
	# silently swallows their failures with `|| true`. We must run it from
	# its own directory or the repo block never gets inserted.
	if ! (cd "${tmpdir}/cachyos-repo" && sudo bash ./cachyos-repo.sh --install); then
		log_warn "CachyOS installer exited non-zero (often the trailing"
		log_warn "  'pacman -Syu' step). Verifying repo was still added..."
	fi

	if ! grep -qE '^\[cachyos(-v[34]|-znver4)?\]' "$PACMAN_CONF"; then
		log_error "CachyOS repo not present in ${PACMAN_CONF} after installer ran."
		log_error "Last 30 lines of ${PACMAN_CONF}:"
		tail -n 30 "$PACMAN_CONF" | sed 's/^/  /' >&2
		fail "CachyOS repo setup failed"
		return 1
	fi

	log_info "CachyOS repo installed"
}

# -----------------------------------------------------------------------------
# Chaotic-AUR repo
# -----------------------------------------------------------------------------
# https://aur.chaotic.cx/
setup_chaotic_aur() {
	if grep -q '^\[chaotic-aur\]' "$PACMAN_CONF"; then
		log_info "chaotic-aur repo already configured"
		return 0
	fi

	log_info "Installing chaotic-aur key and mirrorlist..."

	# Receive and locally sign the chaotic key. Keyserver flakiness is the
	# most common failure mode here — bail cleanly so other repos still get
	# a chance.
	if ! sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com; then
		fail "Failed to fetch chaotic-aur signing key from keyserver.ubuntu.com"
		return 1
	fi
	if ! sudo pacman-key --lsign-key 3056513887B78AEB; then
		fail "Failed to locally sign chaotic-aur key"
		return 1
	fi

	# Install keyring + mirrorlist packages from the chaotic CDN
	if ! sudo pacman -U --noconfirm \
		'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
		'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'; then
		fail "Failed to install chaotic-aur keyring/mirrorlist packages"
		return 1
	fi

	# Append repo block to pacman.conf if not already there
	if ! grep -q '^\[chaotic-aur\]' "$PACMAN_CONF"; then
		log_info "Appending [chaotic-aur] to ${PACMAN_CONF}"
		sudo tee -a "$PACMAN_CONF" >/dev/null <<'EOF'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
	fi

	if ! grep -q '^\[chaotic-aur\]' "$PACMAN_CONF"; then
		log_error "chaotic-aur repo not present in ${PACMAN_CONF} after setup."
		log_error "Last 20 lines of ${PACMAN_CONF}:"
		tail -n 20 "$PACMAN_CONF" | sed 's/^/  /' >&2
		fail "chaotic-aur repo setup failed"
		return 1
	fi

	log_info "chaotic-aur repo installed"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	log_info "setup-repos.sh version: ${SCRIPT_VERSION}"
	require_arch

	# Each repo is independent — a failure in one (e.g. CachyOS mirror down)
	# should not prevent the others from being configured. We track failures
	# and report at the end. The caller (bootstrap.sh) treats this whole
	# script as best-effort.
	local failed=()

	enable_multilib || failed+=("multilib")
	setup_cachyos_repo || failed+=("cachyos")
	setup_chaotic_aur || failed+=("chaotic-aur")

	log_info "Refreshing pacman databases..."
	sudo pacman -Sy || log_warn "pacman -Sy failed; databases may be stale"

	if ((${#failed[@]} > 0)); then
		log_warn "Some repos failed to configure: ${failed[*]}"
		log_warn "Packages depending on those repos will be skipped by bootstrap"
		exit 1
	fi

	log_info "Repository setup complete"
	log_info ""
	log_info "Next step: install the CachyOS extras you want, e.g."
	log_info "  just setup-cachyos-extras   # cachyos-settings + chwd"
	log_info "  just hwdetect               # auto-install hardware drivers (after reboot)"
	log_info ""
	log_info "Other packages now installable from these repos:"
	log_info "  - linux-cachyos          (optimized kernel)"
	log_info "  - cachyos-gaming-meta    (gaming bundle)"
	log_info "  - proton-cachyos         (optimized Proton)"
	log_info "  - proton-ge-custom-bin   (via chaotic-aur)"
	log_info "See docs/GAMING.md for the full list."
}

main "$@"
