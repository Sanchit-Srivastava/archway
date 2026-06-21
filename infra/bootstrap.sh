#!/usr/bin/env bash
set -eEuo pipefail

# Bootstrap script: idempotent system baseline installer
# Applies pacman packages, AUR packages (via yay), and enables systemd services

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/autologin.sh
. "${SCRIPT_DIR}/lib/autologin.sh"

# Preserve the shared implementation from the library under a different name,
# because we override configure_sddm_autologin() with a local wrapper below.
if declare -f configure_sddm_autologin >/dev/null 2>&1; then
	eval "$(declare -f configure_sddm_autologin | sed 's/configure_sddm_autologin()/_shared_configure_sddm_autologin()/')"
fi

# Script metadata
SCRIPT_VERSION="2026-06-21-1"

# Current phase tracking for error messages (used by custom on_error/die)
CURRENT_PHASE="initialization"

# Note: log_* and array_contains come from lib/common.sh
# We keep a bootstrap-specific die() for richer messaging.
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
	log_fatal "BOOTSTRAP FAILED"
	log_fatal "Phase: ${CURRENT_PHASE}"
	log_fatal "Exit code: ${code}"
	log_fatal "Line ${line}: ${cmd}"
	log_fatal "Not all system configuration was applied."
	log_fatal "To retry: ./infra/bootstrap.sh"
}

on_exit() {
	local code="$1"
	# Suppress messages for help/early-exit paths
	if [[ "${BOOTSTRAP_STARTED:-0}" -eq 0 ]]; then
		return
	fi
	if [[ "$code" -eq 0 ]]; then
		log_info "Bootstrap finished successfully"
	else
		log_warn "Bootstrap exited with code ${code}"
	fi
}

trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR
trap 'on_exit "$?"' EXIT

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

check_prerequisites() {
	log_info "Running pre-flight checks..."

	# Check if running on Arch Linux
	if [[ ! -f /etc/arch-release ]]; then
		die "This script must run on Arch Linux (no /etc/arch-release found)"
	fi

	# Check network connectivity
	if ! ping -c 1 -W 5 archlinux.org >/dev/null 2>&1; then
		die "No network connectivity to archlinux.org - check your internet connection"
	fi

	# Check sudo access
	if ! sudo -n true 2>/dev/null; then
		log_warn "Sudo password required"
		sudo -v
	fi

	# Check disk space (need at least 5GB free)
	local available_gb
	available_gb=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
	if [[ "$available_gb" -lt 5 ]]; then
		die "Insufficient disk space. Need at least 5GB free, found ${available_gb}GB"
	fi

	log_info "Pre-flight checks passed"
}

# =============================================================================
# MULTILIB REPO
# =============================================================================
# 32-bit support is needed for Steam, Wine, and a handful of common tools.
# This is a stock Arch repo — just needs uncommenting in /etc/pacman.conf.
#
# Optional third-party repos (CachyOS, chaotic-aur) are NOT configured by
# bootstrap. They were previously auto-enabled but caused more friction
# (keyserver flakiness, upstream installer changes, mirror outages) than
# benefit. To opt in, run `just setup-repos` (see infra/setup-repos.sh).

# Refresh the pacman mirrorlist before doing any package work. archinstall
# sometimes leaves a stale or slow mirrorlist, which manifests as multi-minute
# hangs or signature failures during the big first-run upgrade. reflector
# rewrites /etc/pacman.d/mirrorlist with the 20 fastest HTTPS mirrors.
# Idempotent: re-running just re-sorts. Safe to skip if reflector itself
# can't be installed (we fall back to whatever's already on disk).
refresh_mirrors() {
	log_info "Refreshing pacman mirrorlist via reflector..."
	if ! command -v reflector >/dev/null 2>&1; then
		if ! sudo pacman -S --noconfirm --needed reflector 2>/dev/null; then
			log_warn "Could not install reflector — keeping existing mirrorlist"
			return 0
		fi
	fi
	if ! sudo reflector --latest 20 --protocol https --sort rate \
		--save /etc/pacman.d/mirrorlist 2>/dev/null; then
		log_warn "reflector failed — keeping existing mirrorlist"
		return 0
	fi
	log_info "Mirrorlist refreshed (top 20 HTTPS mirrors by rate)"
}

# Refresh archlinux-keyring and then upgrade the system *once*. If the
# install media is even a few weeks old, master keys may have rotated since
# its ISO build, and `pacman -Syu` will fail with "marginal trust" or
# "invalid or corrupted package" errors before anything gets installed.
# Refreshing the keyring first sidesteps the most common cold-start failure.
#
# This replaces the per-tier `pacman -Syu` that install_pacman_packages used
# to run (which fired four times on a full install, redundantly). With this
# function called once from main(), each tier only installs its own delta.
refresh_keyring_and_upgrade() {
	log_info "Refreshing archlinux-keyring (avoids stale-key failures on fresh ISOs)..."
	sudo pacman -Sy --noconfirm --needed archlinux-keyring

	log_info "Performing initial full-system upgrade (runs once, not per-tier)..."
	# --ask 4: auto-confirm replacement of conflicting packages (e.g.
	# nodejs vs nodejs-lts-jod) without prompting.
	sudo pacman -Syu --noconfirm --ask 4
}

enable_multilib() {
	local pacman_conf="/etc/pacman.conf"
	if pacman-conf --repo=multilib >/dev/null 2>&1; then
		log_info "multilib repo already enabled"
		return 0
	fi

	log_info "Enabling [multilib] repo in ${pacman_conf}"
	# Uncomment the [multilib] section header AND the Include line that
	# follows it. Idempotent: only matches a still-commented block.
	sudo sed -i '/^\s*#\s*\[multilib\]/{
		s/^\s*#\s*//
		n
		s/^\s*#\s*//
	}' "$pacman_conf"

	if ! pacman-conf --repo=multilib >/dev/null 2>&1; then
		log_warn "Failed to enable [multilib] in ${pacman_conf} - inspect manually"
		return 0
	fi

	log_info "Refreshing pacman databases for new multilib repo..."
	sudo pacman -Sy || log_warn "pacman -Sy failed; databases may be stale"
}

# =============================================================================
# YAY AUR HELPER
# =============================================================================

install_yay() {
	if command -v yay >/dev/null 2>&1; then
		log_info "yay already installed"
		return 0
	fi

	log_info "Installing yay AUR helper..."

	# Install base-devel and git if not present
	sudo pacman -S --needed --noconfirm base-devel git

	# Build yay in /tmp
	local tmpdir
	tmpdir=$(mktemp -d)
	cd "$tmpdir"

	log_info "Cloning yay from AUR"
	git clone https://aur.archlinux.org/yay.git
	cd yay
	log_info "Building and installing yay"
	makepkg -si --noconfirm

	cd "$REPO_ROOT"
	rm -rf "$tmpdir"

	log_info "yay installed successfully"
}

# =============================================================================
# PACKAGE INSTALLATION
# =============================================================================

install_pacman_packages() {
	local pkg_file="${1:?install_pacman_packages requires a package list path}"
	# --skip-unavailable: warn and skip packages not found in any configured
	# repo rather than failing. Used for T4 where optional third-party repos
	# (CachyOS, chaotic-aur — opt-in via `just setup-repos`) may not be
	# configured.
	local skip_unavailable=0
	if [[ "${2:-}" == "--skip-unavailable" ]]; then
		skip_unavailable=1
	fi

	if [[ ! -f "$pkg_file" ]]; then
		log_warn "No pacman package list found at $pkg_file"
		return 0
	fi

	# Read packages, ignoring comments and empty lines
	local packages=()
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// /}" ]] && continue
		packages+=("$line")
	done <"$pkg_file"

	if [[ ${#packages[@]} -eq 0 ]]; then
		log_info "No pacman packages to install"
		return 0
	fi

	# Deduplicate the package list (preserves order, keeps first occurrence)
	local seen_pkgs=()
	local unique_packages=()
	local pkg
	for pkg in "${packages[@]}"; do
		if ! array_contains "$pkg" "${seen_pkgs[@]+"${seen_pkgs[@]}"}"; then
			seen_pkgs+=("$pkg")
			unique_packages+=("$pkg")
		else
			log_warn "Duplicate package in $pkg_file: $pkg (skipping)"
		fi
	done
	packages=("${unique_packages[@]}")

	# Pre-validate: check which packages actually exist in the repos.
	# Fast path: single pacman -Si call when everything is present (common case).
	# Only falls back to per-pkg enumeration on problems.
	log_info "Validating ${#packages[@]} packages against repos..."
	local valid_packages=("${packages[@]}")
	local invalid_packages=()
	if ! pacman -Si "${packages[@]}" &>/dev/null; then
		valid_packages=()
		invalid_packages=()
		for pkg in "${packages[@]}"; do
			if pacman -Si "$pkg" &>/dev/null; then
				valid_packages+=("$pkg")
			else
				invalid_packages+=("$pkg")
			fi
		done
	fi

	if [[ ${#invalid_packages[@]} -gt 0 ]]; then
		if [[ "$skip_unavailable" -eq 1 ]]; then
			log_warn "The following packages were NOT found in any configured repo (skipping):"
			for pkg in "${invalid_packages[@]}"; do
				log_warn "  - $pkg"
			done
			log_warn "If these require optional third-party repos, run: just setup-repos"
			# Proceed with only the valid subset
			packages=("${valid_packages[@]}")
			if [[ ${#packages[@]} -eq 0 ]]; then
				log_info "No packages remaining after skipping unavailable ones"
				return 0
			fi
		else
			log_error "The following packages were NOT found in any configured pacman repo:"
			for pkg in "${invalid_packages[@]}"; do
				log_error "  - $pkg"
			done
			log_error ""
			log_error "Possible causes:"
			log_error "  - Package name is wrong or has been renamed"
			log_error "  - Package is AUR-only (move it to pkgs/40-extras.aur.txt)"
			log_error "  - Repos need refreshing (try: sudo pacman -Sy)"
			log_error ""
			log_error "Fix ${pkg_file} and re-run bootstrap."
			return 1
		fi
	fi

	# NOTE: the full-system upgrade (`pacman -Syu`) is NOT performed here.
	# It runs exactly once at bootstrap startup (refresh_keyring_and_upgrade
	# in main()) so a 4-tier full install doesn't redundantly re-upgrade the
	# whole system four times. Each tier only installs its own delta.
	log_info "Installing ${#packages[@]} pacman packages..."
	if ! sudo pacman -S --needed --noconfirm "${packages[@]}"; then
		log_error "pacman failed to install one or more packages from ${pkg_file}."
		log_error "pacman prints the offending package(s) above. To debug:"
		log_error "  sudo pacman -S <package-name>"
		return 1
	fi
	log_info "All pacman packages installed successfully"
}

install_aur_packages() {
	local pkg_file="${1:?install_aur_packages requires a package list path}"

	if [[ ! -f "$pkg_file" ]]; then
		log_warn "No AUR package list found at $pkg_file"
		return 0
	fi

	# Read packages, ignoring comments and empty lines
	local packages=()
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// /}" ]] && continue
		packages+=("$line")
	done <"$pkg_file"

	if [[ ${#packages[@]} -eq 0 ]]; then
		log_info "No AUR packages to install"
		return 0
	fi

	log_info "Installing ${#packages[@]} AUR packages..."
	if ! yay -S --needed --noconfirm "${packages[@]}"; then
		log_warn "yay failed to build/install one or more AUR packages from ${pkg_file}."
		log_warn "AUR (T4) is allowed to fail without bricking the system. yay prints the"
		log_warn "offending package(s) above. To debug: yay -S <package-name>"
		return 1
	fi
	log_info "All AUR packages installed successfully"
}

# =============================================================================
# SYSTEMD SERVICES
# =============================================================================

# Enable the system services listed in a tier's services file.
#
# Note: we do NOT special-case display managers. archinstall enables one
# (SDDM, or Plasma Login Manager on newer releases) and archway accepts that
# choice rather than swapping it. Don't list a display manager in the services
# files — if you ever want to change it, do so deliberately, not via bootstrap.
enable_services() {
	local svc_file="${1:?enable_services requires a services list path}"

	if [[ ! -f "$svc_file" ]]; then
		log_warn "No services list found at $svc_file"
		return 0
	fi

	# Read services, ignoring comments and empty lines
	local services=()
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// /}" ]] && continue
		services+=("$line")
	done <"$svc_file"

	if [[ ${#services[@]} -eq 0 ]]; then
		log_info "No services to enable"
		return 0
	fi

	log_info "Enabling ${#services[@]} systemd services..."

	for service in "${services[@]}"; do
		if systemctl is-enabled "$service" >/dev/null 2>&1; then
			log_info "Service $service already enabled"
		else
			log_info "Enabling service: $service"
			sudo systemctl enable "$service"
		fi
	done
}

# Enable user-level services that archway specifically owns. The PipeWire stack
# and xdg-desktop-portal are enabled by their own packages under Plasma, so we
# only manage the repo-specific timer here.
enable_user_services() {
	log_info "Enabling user-level systemd services..."

	local user_services=(
		"vdirsyncer.timer"
	)

	for service in "${user_services[@]}"; do
		if systemctl --user is-enabled "$service" >/dev/null 2>&1; then
			log_info "User service $service already enabled"
		else
			log_info "Enabling user service: $service"
			systemctl --user enable "$service"
		fi
	done
}

# =============================================================================
# PAM & PORTALS — intentionally NOT configured here
# =============================================================================
# Earlier versions of this script used awk/sed to surgically insert lines into
# /etc/pam.d/{login,sddm,system-auth,system-local-login} for gnome-keyring and
# fprintd, and wrote a system-wide xdg portals.conf. Those in-place edits to
# auth files are fragile on a rolling release (a pambase update can shift the
# format and lock you out) and mostly duplicated what the desktop already does:
#   - KDE Plasma ships a working keyring/wallet and a ready /etc/pam.d/
#     kde-fingerprint for the lock screen.
#   - niri's portal needs are handled per-session, not system-wide.
# These are now one-time, documented manual steps. See docs/STABILITY.md
# ("Fingerprint, keyring, and portals") for the exact commands.

# =============================================================================
# BOOTLOADER — intentionally NOT configured here
# =============================================================================
# archinstall installs systemd-boot, registers the EFI boot entry, and ships
# auto-discovered UKIs in EFI/Linux/. Re-running `bootctl install` / authoring
# loader.conf from this script only duplicated that work and was the riskiest
# code in the file (it writes to the ESP). If the firmware ever loses the boot
# entry (e.g. a ThinkPad NVRAM wipe), that's a one-command recovery, not a
# bootstrap concern — see docs/STABILITY.md and `infra/fix-boot.sh`.

# =============================================================================
# KEYD CONFIGURATION (keyboard remapping)
# =============================================================================

configure_keyd() {
	log_info "Configuring keyd (keyboard remapping)..."

	if ! command -v keyd >/dev/null 2>&1; then
		log_warn "keyd not installed - skipping keyboard remapping configuration"
		return 0
	fi

	local keyd_src="${REPO_ROOT}/dots/keyd/default.conf"
	local keyd_dst="/etc/keyd/default.conf"

	if [[ ! -f "$keyd_src" ]]; then
		log_warn "keyd config not found at $keyd_src - skipping"
		return 0
	fi

	sudo mkdir -p /etc/keyd

	# Only update if the config has changed (avoids unnecessary service restarts)
	if [[ -f "$keyd_dst" ]] && diff -q "$keyd_src" "$keyd_dst" >/dev/null 2>&1; then
		log_info "keyd config already up to date"
	else
		sudo cp "$keyd_src" "$keyd_dst"
		sudo chmod 644 "$keyd_dst"
		log_info "Deployed keyd config to $keyd_dst"

		# Reload keyd if the service is running (picks up config changes live)
		if systemctl is-active keyd >/dev/null 2>&1; then
			sudo keyd reload
			log_info "Reloaded keyd daemon"
		fi
	fi
}

# =============================================================================
# SDDM AUTOLOGIN
# =============================================================================

configure_sddm_autologin() {
	if [[ "${ARCHWAY_SKIP_SDDM_AUTOLOGIN:-}" == "1" ]]; then
		log_info "Skipping SDDM autologin (ARCHWAY_SKIP_SDDM_AUTOLOGIN=1)"
		return 0
	fi

	local autologin_conf="/etc/sddm.conf.d/autologin.conf"
	local autologin_user="${SUDO_USER:-$USER}"
	local autologin_session=""

	# Session selection order (policy local to bootstrap):
	#   1. ARCHWAY_AUTOLOGIN_SESSION env var (explicit override)
	#   2. niri (if present — user opted into DMS)
	#   3. plasma (archinstall baseline)
	#   4. plasmawayland
	if [[ -n "${ARCHWAY_AUTOLOGIN_SESSION:-}" ]]; then
		autologin_session="$ARCHWAY_AUTOLOGIN_SESSION"
		log_info "Using ARCHWAY_AUTOLOGIN_SESSION override: $autologin_session"
	else
		autologin_session="$(detect_sddm_session)"
	fi

	if [[ -z "$autologin_session" ]]; then
		log_warn "No known SDDM session found (plasma/niri). Skipping autologin configuration"
		return 0
	fi

	# Skip if running as root without SUDO_USER (can't determine target user)
	if [[ -z "$autologin_user" || "$autologin_user" == "root" ]]; then
		log_warn "Cannot determine autologin user - skipping autologin configuration"
		log_warn "To enable autologin manually, create $autologin_conf with:"
		log_warn "  [Autologin]"
		log_warn "  User=yourusername"
		log_warn "  Session=$autologin_session"
		return 0
	fi

	# Delegate the idempotent write (and its internal "already configured" check)
	# to the shared helper. Pass "sudo" as the privilege command.
	_shared_configure_sddm_autologin "$autologin_user" "$autologin_session" "$autologin_conf" "sudo"

	# Extra bootstrap-specific note
	if [[ -f "$autologin_conf" ]]; then
		log_info "Note: Autologin is secure when using full disk encryption"
	fi
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

	if ! command -v zsh >/dev/null 2>&1; then
		log_warn "zsh not installed - skipping shell change"
		return 0
	fi

	log_info "Changing default shell to zsh..."
	chsh -s "$(which zsh)"
	log_info "Default shell changed to zsh (will take effect on next login)"
}

# =============================================================================
# TIER DISPATCH
# =============================================================================

# Run a single tier's package install + service enable + per-tier configuration.
# Returns non-zero on failure but does NOT abort the script (caller decides).
run_tier() {
	local tier="$1"
	local prefix
	case "$tier" in
	1) prefix="10-base" ;;
	2) prefix="20-shell" ;;
	3) prefix="30-desktop" ;;
	4) prefix="40-extras" ;;
	*)
		log_error "Unknown tier: $tier"
		return 1
		;;
	esac
	local pkg_file="${SCRIPT_DIR}/pkgs/${prefix}.txt"
	local svc_file="${SCRIPT_DIR}/services/${prefix}.txt"
	local aur_file="${SCRIPT_DIR}/pkgs/${prefix}.aur.txt"

	log_info ""
	log_info "═══════════════════════════════════════════════════════════════════"
	log_info "TIER ${tier} (${prefix})"
	log_info "═══════════════════════════════════════════════════════════════════"

	CURRENT_PHASE="tier ${tier}: installing pacman packages"
	if [[ -f "$pkg_file" ]]; then
		# T4 is best-effort: packages from optional repos (CachyOS, chaotic-aur
		# — opt-in via `just setup-repos`) are skipped rather than aborting if
		# those repos weren't configured.
		if [[ "$tier" -eq 4 ]]; then
			install_pacman_packages "$pkg_file" --skip-unavailable || return 1
		else
			install_pacman_packages "$pkg_file" || return 1
		fi
	fi

	# AUR packages: only T4 ships an AUR list today, but support any tier.
	if [[ -f "$aur_file" ]]; then
		CURRENT_PHASE="tier ${tier}: installing AUR packages"
		install_aur_packages "$aur_file" || return 1
	fi

	CURRENT_PHASE="tier ${tier}: enabling systemd services"
	if [[ -f "$svc_file" ]]; then
		enable_services "$svc_file" || return 1
	fi

	# Per-tier configuration steps
	case "$tier" in
	1)
		CURRENT_PHASE="tier 1: configuring keyd"
		configure_keyd
		;;
	2)
		# User-level setup (skip if running as root)
		if [[ $EUID -ne 0 ]]; then
			CURRENT_PHASE="tier 2: setting default shell to zsh"
			set_default_shell
		else
			log_warn "Running as root - skipping shell change"
		fi
		;;
	3)
		CURRENT_PHASE="tier 3: configuring SDDM autologin"
		configure_sddm_autologin

		# User-level graphical session services
		if [[ $EUID -ne 0 ]]; then
			CURRENT_PHASE="tier 3: enabling user systemd services"
			enable_user_services
		else
			log_warn "Running as root - skipping user service setup"
		fi
		;;
	esac

	log_info "Tier ${tier} complete"
	return 0
}

# =============================================================================
# CLI
# =============================================================================

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Tiered system bootstrap. Runs tiers in order; a failed tier stops higher
tiers but lower tiers remain applied.

Tiers:
  1 = base     Core OS plumbing (network, audio, bluetooth, fonts, polkit)
  2 = shell    CLI tools, editors, secrets, zsh
  3 = desktop  KDE Plasma fallback graphical session (DM from archinstall)
  4 = extras   AUR packages, DMS, niri, messaging apps (fragile)

Options:
  --tier N        Run only tier N (1-4)
  --up-to N       Run tiers 1..N inclusive
  --tiers LIST    Run a comma-separated list of tiers (e.g. 1,2,3)
  -h, --help      Show this help

Default: --up-to 4 (all tiers)
EOF
}

parse_args() {
	TIERS_TO_RUN=(1 2 3 4)
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--tier)
			[[ $# -ge 2 ]] || die "--tier requires a value"
			TIERS_TO_RUN=("$2")
			shift 2
			;;
		--up-to)
			[[ $# -ge 2 ]] || die "--up-to requires a value"
			local n="$2"
			[[ "$n" =~ ^[1-4]$ ]] || die "--up-to must be 1..4"
			TIERS_TO_RUN=()
			local i
			for ((i = 1; i <= n; i++)); do TIERS_TO_RUN+=("$i"); done
			shift 2
			;;
		--tiers)
			[[ $# -ge 2 ]] || die "--tiers requires a value"
			IFS=',' read -r -a TIERS_TO_RUN <<<"$2"
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			log_error "Unknown argument: $1"
			usage
			exit 1
			;;
		esac
	done

	# Validate
	local t
	for t in "${TIERS_TO_RUN[@]}"; do
		[[ "$t" =~ ^[1-4]$ ]] || die "Invalid tier: $t (must be 1..4)"
	done
}

# =============================================================================
# MAIN
# =============================================================================

main() {
	BOOTSTRAP_STARTED=1
	log_info "Bootstrap script version: ${SCRIPT_VERSION}"
	log_info "Starting archway bootstrap..."
	log_info "Repository: $REPO_ROOT"
	log_info "Tiers requested: ${TIERS_TO_RUN[*]}"

	local state_dir
	state_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/archway"

	CURRENT_PHASE="pre-flight checks"
	check_prerequisites

	CURRENT_PHASE="refreshing pacman mirrorlist"
	refresh_mirrors

	CURRENT_PHASE="enabling multilib repo"
	enable_multilib

	CURRENT_PHASE="refreshing keyring + initial system upgrade"
	refresh_keyring_and_upgrade

	# yay is required only when an AUR tier is requested (currently T4)
	if array_contains 4 "${TIERS_TO_RUN[@]}"; then
		CURRENT_PHASE="installing yay (AUR helper)"
		install_yay
	fi

	mkdir -p "$state_dir"

	local tier
	local failed_tiers=()
	for tier in "${TIERS_TO_RUN[@]}"; do
		if run_tier "$tier"; then
			:
		else
			log_error "Tier ${tier} failed; lower tiers (if any) remain valid."
			failed_tiers+=("$tier")
			# Per design: T4 failure must not abort lower tiers, but we should
			# stop processing higher tiers in this run since they may depend on it.
			break
		fi
	done

	# Completion marker — gates install-dms.sh (it checks the system baseline is
	# present before installing DMS). Written only if all requested tiers
	# succeeded AND tier 1 was included (a meaningful baseline run).
	if [[ ${#failed_tiers[@]} -eq 0 ]] && array_contains 1 "${TIERS_TO_RUN[@]}"; then
		local state_file="${state_dir}/bootstrap.complete"
		cat >"$state_file" <<EOF
BOOTSTRAP_VERSION="${SCRIPT_VERSION}"
BOOTSTRAP_TIERS="${TIERS_TO_RUN[*]}"
BOOTSTRAP_COMPLETED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPO_ROOT="${REPO_ROOT}"
EOF
		log_info "Wrote bootstrap marker: $state_file"
	fi

	CURRENT_PHASE="complete"
	if [[ ${#failed_tiers[@]} -gt 0 ]]; then
		log_warn "Bootstrap finished with failed tiers: ${failed_tiers[*]}"
		log_warn "Re-run a single tier with: ./infra/bootstrap.sh --tier ${failed_tiers[0]}"
		exit 1
	fi

	log_info "Bootstrap complete!"
	log_info ""
	log_info "Next steps:"
	log_info "  1. Reboot to start the graphical login screen"
	log_info "  2. Apply dotfiles: ./infra/dotfiles.sh"
	log_info "  3. Install DMS (optional): ./install-dms.sh"
	log_info "  4. Validate: ./infra/doctor.sh"
}

parse_args "$@"
main
