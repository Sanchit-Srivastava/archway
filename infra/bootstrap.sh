#!/usr/bin/env bash
set -eEuo pipefail

# Bootstrap script: idempotent system baseline installer
# Applies pacman packages, AUR packages (via yay), and enables systemd services

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Script metadata
SCRIPT_VERSION="2026-05-08-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Current phase tracking for error messages
CURRENT_PHASE="initialization"

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
log_fatal() { printf "${RED}[FATAL]${NC} %s\n" "$1" >&2; }

# Helper to exit with a clear error message
die() {
	log_fatal "$1"
	log_fatal "Phase: ${CURRENT_PHASE}"
	log_fatal "Bootstrap did NOT complete. Fix the error above and re-run."
	exit 1
}

array_contains() {
	local needle="$1"
	shift
	local item
	for item in "$@"; do
		if [[ "$item" == "$needle" ]]; then
			return 0
		fi
	done
	return 1
}

on_error() {
	local line="$1"
	local cmd="$2"
	local code="$3"
	echo "" >&2
	printf "%s╔══════════════════════════════════════════════════════════════════╗%s\n" "${RED}${BOLD}" "${NC}" >&2
	printf "%s║                      BOOTSTRAP FAILED                            ║%s\n" "${RED}${BOLD}" "${NC}" >&2
	printf "%s╚══════════════════════════════════════════════════════════════════╝%s\n" "${RED}${BOLD}" "${NC}" >&2
	echo "" >&2
	log_fatal "Phase: ${CURRENT_PHASE}"
	log_fatal "Exit code: ${code}"
	log_fatal "Line ${line}: ${cmd}"
	echo "" >&2
	log_fatal "Bootstrap did NOT complete successfully."
	log_fatal "Not all system configuration was applied."
	log_fatal ""
	log_fatal "To retry: ./infra/bootstrap.sh"
	log_fatal "To debug: Run the failed command manually and check its output"
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

	# Pre-validate: check which packages actually exist in the repos
	log_info "Validating ${#packages[@]} packages against repos..."
	local valid_packages=()
	local invalid_packages=()
	for pkg in "${packages[@]}"; do
		if pacman -Si "$pkg" &>/dev/null; then
			valid_packages+=("$pkg")
		else
			invalid_packages+=("$pkg")
		fi
	done

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

	# Upgrade existing packages first, separately from installing new ones.
	# Combining -Syu with a package list causes pacman to refuse non-interactively
	# when an installed package conflicts with a newly-requested one (e.g. nodejs
	# vs nodejs-lts-jod). Splitting into two steps lets pacman resolve conflicts
	# cleanly at install time without hardcoding workarounds.
	log_info "Upgrading existing packages..."
	sudo pacman -Syu --noconfirm --ask 4

	log_info "Installing ${#packages[@]} pacman packages..."
	if sudo pacman -S --needed --noconfirm "${packages[@]}"; then
		log_info "All pacman packages installed successfully"
		return 0
	fi

	# Bulk install failed — fall back to one-by-one to identify the culprit(s)
	log_warn "Bulk install failed. Installing packages individually to identify failures..."
	local failed_packages=()
	local succeeded=0
	for pkg in "${packages[@]}"; do
		if sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null; then
			succeeded=$((succeeded + 1))
		else
			log_error "Failed to install: $pkg"
			failed_packages+=("$pkg")
		fi
	done

	if [[ ${#failed_packages[@]} -gt 0 ]]; then
		log_error ""
		log_error "═══════════════════════════════════════════════════════════════════"
		log_error "PACMAN INSTALL SUMMARY: ${#failed_packages[@]} package(s) failed"
		log_error "═══════════════════════════════════════════════════════════════════"
		for pkg in "${failed_packages[@]}"; do
			log_error "  FAILED: $pkg"
		done
		log_error ""
		log_error "Succeeded: ${succeeded}  |  Failed: ${#failed_packages[@]}  |  Total: ${#packages[@]}"
		log_error ""
		log_error "To debug a failure, run manually:"
		log_error "  sudo pacman -S <package-name>"
		return 1
	fi

	log_info "All pacman packages installed successfully (via individual fallback)"
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
	if yay -S --needed --noconfirm "${packages[@]}"; then
		log_info "All AUR packages installed successfully"
		return 0
	fi

	# Bulk install failed — fall back to one-by-one to identify the culprit(s)
	log_warn "Bulk AUR install failed. Installing packages individually to identify failures..."
	local failed_packages=()
	local succeeded=0
	local pkg
	for pkg in "${packages[@]}"; do
		if yay -S --needed --noconfirm "$pkg" &>/dev/null; then
			succeeded=$((succeeded + 1))
		else
			log_error "Failed to install AUR package: $pkg"
			failed_packages+=("$pkg")
		fi
	done

	if [[ ${#failed_packages[@]} -gt 0 ]]; then
		log_error ""
		log_error "═══════════════════════════════════════════════════════════════════"
		log_error "AUR INSTALL SUMMARY: ${#failed_packages[@]} package(s) failed"
		log_error "═══════════════════════════════════════════════════════════════════"
		for pkg in "${failed_packages[@]}"; do
			log_error "  FAILED: $pkg"
		done
		log_error ""
		log_error "Succeeded: ${succeeded}  |  Failed: ${#failed_packages[@]}  |  Total: ${#packages[@]}"
		log_error ""
		log_error "To debug a failure, run manually:"
		log_error "  yay -S <package-name>"
		return 1
	fi

	log_info "All AUR packages installed successfully (via individual fallback)"
}

# =============================================================================
# SYSTEMD SERVICES
# =============================================================================

# Known display manager service names
DISPLAY_MANAGERS=(sddm lightdm gdm lxdm ly greetd plasmalogin)

is_display_manager() {
	local svc="$1"
	local dm
	for dm in "${DISPLAY_MANAGERS[@]}"; do
		if [[ "$svc" == "$dm" || "$svc" == "${dm}.service" ]]; then
			return 0
		fi
	done
	return 1
}

# Swap in the desired display manager, disabling any existing one first.
enable_display_manager() {
	local desired="$1"
	local dm_link="/etc/systemd/system/display-manager.service"

	if systemctl is-enabled "$desired" >/dev/null 2>&1; then
		log_info "Display manager $desired already enabled"
		return 0
	fi

	# If another DM holds the display-manager.service slot, disable it first
	if [[ -L "$dm_link" ]]; then
		local current
		current="$(basename "$(readlink -f "$dm_link")")"
		log_warn "Replacing display manager ${current} with ${desired}"
		sudo systemctl disable "${current}" 2>/dev/null || true
	fi

	log_info "Enabling display manager: $desired"
	sudo systemctl enable "$desired"
}

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
		if is_display_manager "$service"; then
			enable_display_manager "$service"
		elif systemctl is-enabled "$service" >/dev/null 2>&1; then
			log_info "Service $service already enabled"
		else
			log_info "Enabling service: $service"
			sudo systemctl enable "$service"
		fi
	done
}

enable_user_services() {
	log_info "Enabling user-level systemd services..."

	local user_services=(
		"pipewire"
		"pipewire-pulse"
		"wireplumber"
		"xdg-desktop-portal"
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
# PAM CONFIGURATION
# =============================================================================

configure_pam_keyring() {
	log_info "Configuring PAM for gnome-keyring..."

	local pam_files=(
		"/etc/pam.d/login"
		"/etc/pam.d/sddm"
	)

	local auth_line="auth       optional     pam_gnome_keyring.so"
	local session_line="session    optional     pam_gnome_keyring.so auto_start"

	for pam_file in "${pam_files[@]}"; do
		if [[ ! -f "$pam_file" ]]; then
			log_warn "PAM file not found: $pam_file (skipping)"
			continue
		fi

		if grep -q "pam_gnome_keyring.so" "$pam_file" 2>/dev/null; then
			log_info "PAM already configured for $pam_file"
			continue
		fi

		log_info "Configuring $pam_file for gnome-keyring..."

		sudo cp "$pam_file" "${pam_file}.backup.$(date +%Y%m%d)"

		if grep -q "^auth.*pam_unix.so" "$pam_file"; then
			sudo awk -v line="$auth_line" '
                /^auth.*pam_unix\.so/ { print; print line; next }
                { print }
            ' "$pam_file" | sudo tee "$pam_file.new" >/dev/null
			sudo mv "$pam_file.new" "$pam_file"
			sudo chmod 644 "$pam_file"
		fi

		if grep -q "^session" "$pam_file"; then
			sudo awk -v line="$session_line" '
                /^session/ && !found { last=NR }
                { lines[NR]=$0 }
                END {
                    for (i=1; i<=NR; i++) {
                        print lines[i]
                        if (i==last) print line
                    }
                }
            ' "$pam_file" | sudo tee "$pam_file.new" >/dev/null
			sudo mv "$pam_file.new" "$pam_file"
			sudo chmod 644 "$pam_file"
		fi

		log_info "Configured $pam_file"
	done
}

configure_pam_fingerprint() {
	log_info "Configuring PAM for fprintd (fingerprint auth)..."

	local pam_files=(
		"/etc/pam.d/system-auth"
		"/etc/pam.d/system-local-login"
	)

	local auth_line="auth       sufficient   pam_fprintd.so"

	for pam_file in "${pam_files[@]}"; do
		if [[ ! -f "$pam_file" ]]; then
			log_warn "PAM file not found: $pam_file (skipping)"
			continue
		fi

		if grep -q "pam_fprintd.so" "$pam_file" 2>/dev/null; then
			log_info "PAM already configured for fingerprint auth: $pam_file"
			continue
		fi

		log_info "Configuring $pam_file for fingerprint auth..."

		sudo cp "$pam_file" "${pam_file}.backup.$(date +%Y%m%d)"

		if grep -q "^auth.*pam_unix.so" "$pam_file"; then
			sudo awk -v line="$auth_line" '
                /^auth.*pam_unix\.so/ { print line; print; next }
                { print }
            ' "$pam_file" | sudo tee "$pam_file.new" >/dev/null
			sudo mv "$pam_file.new" "$pam_file"
			sudo chmod 644 "$pam_file"
		else
			log_warn "No pam_unix.so auth line found in $pam_file (skipping)"
			continue
		fi

		log_info "Configured $pam_file"
	done
}

configure_pam_dms() {
	log_info "Configuring PAM for DMS lock screen..."

	local pam_file="/etc/pam.d/dankshell"

	# Check if already exists with correct order (pam_unix before pam_fprintd)
	if [[ -f "$pam_file" ]] && grep -q "pam_fprintd.so" "$pam_file" 2>/dev/null; then
		if awk '/^auth/ {print; exit}' "$pam_file" | grep -q "pam_unix.so"; then
			log_info "PAM config for DMS lock screen already configured: $pam_file"
			return 0
		fi
	fi

	log_info "Creating $pam_file for DMS lock screen with fingerprint support..."

	# Create PAM config for DMS lock screen
	# - pam_unix.so: password auth (sufficient = succeeds without checking more)
	# - pam_fprintd.so: fingerprint fallback if password fails
	# - pam_deny.so: deny if all auth methods fail
	# Note: pam_unix must come first - if fprintd runs first it blocks waiting
	# for fingerprint and the password input has nowhere to go
	sudo install -m 0644 /dev/null "$pam_file"
	sudo tee "$pam_file" >/dev/null <<'EOF'
# PAM configuration for DankMaterialShell lock screen
# Supports password and fingerprint unlock

# Auth: password first, then fingerprint fallback
auth        sufficient    pam_unix.so nullok
auth        sufficient    pam_fprintd.so
auth        required      pam_deny.so

# Account: use system defaults
account     required      pam_unix.so

# Session: minimal (user already has a session)
session     required      pam_unix.so
EOF
	sudo chmod 644 "$pam_file"

	log_info "Created $pam_file"
}

# =============================================================================
# PORTAL CONFIGURATION
# =============================================================================

configure_portals() {
	log_info "Configuring XDG portals for niri/Wayland..."

	sudo mkdir -p /etc/xdg/xdg-desktop-portal

	local portal_conf="/etc/xdg/xdg-desktop-portal/portals.conf"

	# Check if already configured for gnome/gtk (niri setup)
	if [[ -f "$portal_conf" ]] && grep -q "default=gnome" "$portal_conf"; then
		log_info "Portal configuration already set for niri"
		return 0
	fi

	log_info "Creating portal configuration..."

	# niri uses GNOME portal for screen sharing, GTK for file dialogs
	sudo tee "$portal_conf" >/dev/null <<'EOF'
[preferred]
default=gnome;gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.AppChooser=gtk
org.freedesktop.impl.portal.Screenshot=gnome
org.freedesktop.impl.portal.ScreenCast=gnome
EOF

	log_info "Portal configuration created"
}

# =============================================================================
# SYSTEMD-BOOT CONFIGURATION
# =============================================================================

# Detect mounted ESP. Returns mount path on stdout, or empty on stdout + rc=1.
detect_esp_mount() {
	local mp
	for mp in /efi /boot /boot/efi; do
		if findmnt -n -o FSTYPE "$mp" 2>/dev/null | grep -q '^vfat$'; then
			echo "$mp"
			return 0
		fi
	done
	return 1
}

configure_systemd_boot() {
	log_info "Checking systemd-boot installation..."

	# Only relevant on UEFI systems
	if [[ ! -d /sys/firmware/efi ]]; then
		log_warn "System is not booted in UEFI mode - skipping systemd-boot setup"
		return 0
	fi

	if ! command -v bootctl >/dev/null 2>&1; then
		log_error "bootctl not found (expected from systemd) - skipping"
		return 0
	fi

	local esp
	if ! esp=$(detect_esp_mount); then
		log_warn "Could not detect ESP mount (looked at /efi, /boot, /boot/efi)"
		log_warn "Mount your EFI System Partition first, then re-run bootstrap"
		return 0
	fi
	log_info "ESP detected at: $esp"

	# Idempotent install. bootctl install is safe to skip if already installed;
	# bootctl update will only update if the on-disk binary is older.
	if sudo bootctl --esp-path="$esp" is-installed 2>/dev/null | grep -q '^yes'; then
		log_info "systemd-boot already installed in ESP - running update (no-op if current)"
		sudo bootctl --esp-path="$esp" update || true
	else
		log_info "Installing systemd-boot to $esp ..."
		if ! sudo bootctl --esp-path="$esp" install; then
			log_error "bootctl install failed - leaving existing bootloader in place"
			return 0
		fi
	fi

	# Ensure pacman hook exists so bootctl update runs on systemd upgrades.
	# Arch ships /usr/share/libalpm/hooks/95-systemd-boot.hook out of the box;
	# warn if absent.
	if [[ ! -f /usr/share/libalpm/hooks/95-systemd-boot.hook ]] &&
		[[ ! -f /etc/pacman.d/hooks/95-systemd-boot.hook ]]; then
		log_warn "systemd-boot pacman update hook not found"
		log_warn "Run 'sudo bootctl update' manually after systemd package updates"
	fi

	# Sanity report
	log_info "systemd-boot status:"
	sudo bootctl --esp-path="$esp" status 2>/dev/null | head -20 || true
}

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
# POLKIT CONFIGURATION
# =============================================================================

configure_polkit() {
	log_info "Configuring polkit..."

	if [[ -f /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]]; then
		log_info "Polkit GNOME agent installed"
	else
		log_warn "Polkit GNOME agent not found - install polkit-gnome package"
	fi

	sudo mkdir -p /etc/polkit-1/rules.d

	log_info "Note: DMS provides its own polkit authentication agent"
	log_info "      polkit-gnome is installed as a fallback for non-DMS sessions (e.g., Plasma)"
}

# =============================================================================
# SDDM AUTOLOGIN
# =============================================================================

configure_sddm_autologin() {
	if [[ "${ARCHWAY_SKIP_SDDM_AUTOLOGIN:-}" == "1" ]]; then
		log_info "Skipping SDDM autologin (ARCHWAY_SKIP_SDDM_AUTOLOGIN=1)"
		return 0
	fi

	log_info "Configuring SDDM autologin..."

	local autologin_conf="/etc/sddm.conf.d/autologin.conf"
	local autologin_user="${SUDO_USER:-$USER}"
	local autologin_session=""

	# Session selection order:
	#   1. ARCHWAY_AUTOLOGIN_SESSION env var (explicit user override)
	#      e.g. ARCHWAY_AUTOLOGIN_SESSION=plasma ./infra/bootstrap.sh
	#   2. niri (preferred primary session on archway laptops; installed via
	#      DMS in T4 — if it's present on disk the user has opted into it)
	#   3. plasma (canonical archinstall baseline — fallback when niri is
	#      not installed, e.g. fresh KDE-only baseline before DMS install)
	#   4. plasmawayland (older Plasma session name)
	if [[ -n "${ARCHWAY_AUTOLOGIN_SESSION:-}" ]]; then
		autologin_session="$ARCHWAY_AUTOLOGIN_SESSION"
		log_info "Using ARCHWAY_AUTOLOGIN_SESSION override: $autologin_session"
	elif [[ -f "/usr/share/wayland-sessions/niri.desktop" ]]; then
		autologin_session="niri"
	elif [[ -f "/usr/share/wayland-sessions/plasma.desktop" ]] ||
		[[ -f "/usr/share/xsessions/plasma.desktop" ]]; then
		autologin_session="plasma"
	elif [[ -f "/usr/share/wayland-sessions/plasmawayland.desktop" ]]; then
		autologin_session="plasmawayland"
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

	# Check if already configured for this user AND session (re-run safe;
	# also reapplies if the user changed ARCHWAY_AUTOLOGIN_SESSION).
	if [[ -f "$autologin_conf" ]] &&
		grep -q "User=$autologin_user" "$autologin_conf" 2>/dev/null &&
		grep -q "Session=$autologin_session" "$autologin_conf" 2>/dev/null; then
		log_info "SDDM autologin already configured for $autologin_user → $autologin_session"
		return 0
	fi

	log_info "Enabling SDDM autologin for user: $autologin_user"
	log_info "Session: $autologin_session"

	sudo mkdir -p /etc/sddm.conf.d

	sudo tee "$autologin_conf" >/dev/null <<EOF
# SDDM Autologin Configuration
# Created by archway bootstrap.sh
# Safe with full disk encryption (FDE) - machine is protected at boot

[Autologin]
User=$autologin_user
Session=$autologin_session
EOF

	log_info "SDDM autologin configured"
	log_info "Note: Autologin is secure when using full disk encryption"
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

		CURRENT_PHASE="tier 1: configuring polkit"
		configure_polkit

		CURRENT_PHASE="tier 1: configuring systemd-boot"
		configure_systemd_boot

		;;
	2)
		CURRENT_PHASE="tier 2: configuring PAM for gnome-keyring"
		configure_pam_keyring

		CURRENT_PHASE="tier 2: configuring PAM for fingerprint auth"
		configure_pam_fingerprint

		# User-level setup (skip if running as root)
		if [[ $EUID -ne 0 ]]; then
			CURRENT_PHASE="tier 2: setting default shell to zsh"
			set_default_shell
		else
			log_warn "Running as root - skipping shell change"
		fi
		;;
	3)
		CURRENT_PHASE="tier 3: configuring XDG portals"
		configure_portals

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
	4)
		CURRENT_PHASE="tier 4: configuring PAM for DMS lock screen"
		configure_pam_dms
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
tiers but leaves lower-tier markers intact.

Tiers:
  1 = base     Core OS plumbing (network, audio, bluetooth, fonts, polkit)
  2 = shell    CLI tools, editors, secrets, zsh
  3 = desktop  KDE Plasma + SDDM (fallback graphical session)
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

	CURRENT_PHASE="enabling multilib repo"
	enable_multilib

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
			local marker="${state_dir}/bootstrap.tier${tier}.complete"
			cat >"$marker" <<EOF
BOOTSTRAP_VERSION="${SCRIPT_VERSION}"
BOOTSTRAP_TIER="${tier}"
BOOTSTRAP_COMPLETED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPO_ROOT="${REPO_ROOT}"
EOF
			log_info "Wrote tier marker: $marker"
		else
			log_error "Tier ${tier} failed; lower tiers (if any) remain valid."
			failed_tiers+=("$tier")
			# Per design: T4 failure must not abort lower tiers, but we should
			# stop processing higher tiers in this run since they may depend on it.
			break
		fi
	done

	# Legacy aggregate marker: written only if all requested tiers succeeded
	# AND tier 1 was included (i.e. a meaningful baseline run).
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
	log_info "  1. Reboot to start SDDM (graphical login screen)"
	log_info "  2. Apply dotfiles: ./infra/dotfiles.sh"
	log_info "  3. Install DMS (optional): ./install-dms.sh"
	log_info "  4. Validate: ./infra/doctor.sh"
}

parse_args "$@"
main
