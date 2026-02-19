#!/usr/bin/env bash
set -eEuo pipefail

# Bootstrap script: idempotent system baseline installer
# Applies pacman packages, AUR packages (via yay), and enables systemd services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Script metadata
SCRIPT_VERSION="2026-02-17-1"

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
	local pkg_file="${SCRIPT_DIR}/pkgs.pacman.txt"

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

	log_info "Installing ${#packages[@]} pacman packages..."
	sudo pacman -Syu --needed --noconfirm "${packages[@]}"
}

install_aur_packages() {
	local pkg_file="${SCRIPT_DIR}/pkgs.aur.txt"

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
	yay -S --needed --noconfirm "${packages[@]}"
}

# =============================================================================
# SYSTEMD SERVICES
# =============================================================================

enable_services() {
	local svc_file="${SCRIPT_DIR}/services.system.txt"

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

enable_user_services() {
	log_info "Enabling user-level systemd services..."

	local user_services=(
		"pipewire"
		"pipewire-pulse"
		"wireplumber"
		"xdg-desktop-portal"
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
# SNAPPER / BTRFS CONFIGURATION
# =============================================================================

# Print detailed guidance for manual Btrfs setup
print_btrfs_setup_guidance() {
	log_warn ""
	log_warn "═══════════════════════════════════════════════════════════════════"
	log_warn "MANUAL BTRFS SETUP REQUIRED"
	log_warn "═══════════════════════════════════════════════════════════════════"
	log_warn ""
	log_warn "Expected subvolume layout:"
	log_warn "  @           → /           (root)"
	log_warn "  @home       → /home       (user data)"
	log_warn "  @snapshots  → /.snapshots (snapper snapshots)"
	log_warn "  @var_log    → /var/log    (logs, optional)"
	log_warn ""
	log_warn "To create the @snapshots subvolume manually:"
	log_warn ""
	log_warn "  1. Find your Btrfs device:"
	log_warn "     findmnt -n -o SOURCE /"
	log_warn ""
	log_warn "  2. Mount the top-level subvolume:"
	log_warn "     sudo mount -o subvolid=5 /dev/<device> /mnt"
	log_warn ""
	log_warn "  3. Create the @snapshots subvolume:"
	log_warn "     sudo btrfs subvolume create /mnt/@snapshots"
	log_warn ""
	log_warn "  4. Unmount:"
	log_warn "     sudo umount /mnt"
	log_warn ""
	log_warn "  5. Add to /etc/fstab (use same options as your @ subvolume):"
	log_warn "     <device>  /.snapshots  btrfs  subvol=@snapshots,noatime,compress=zstd  0  0"
	log_warn ""
	log_warn "  6. Mount and re-run bootstrap:"
	log_warn "     sudo mkdir -p /.snapshots"
	log_warn "     sudo mount /.snapshots"
	log_warn "     ./infra/bootstrap.sh"
	log_warn ""
	log_warn "═══════════════════════════════════════════════════════════════════"
}

# Get the Btrfs device for root filesystem
get_btrfs_device() {
	findmnt -n -o SOURCE / | sed 's/\[.*\]//'
}

# Get mount options from an existing Btrfs mount (for consistency)
get_btrfs_mount_options() {
	# Get options from root mount, remove subvol/subvolid specific ones
	findmnt -n -o OPTIONS / | sed -E 's/,?subvol=[^,]*//g; s/,?subvolid=[^,]*//g; s/^,//; s/,$//'
}

# Check if @snapshots subvolume exists
check_snapshots_subvolume_exists() {
	local device="$1"
	local tmpdir
	tmpdir=$(mktemp -d)

	# Mount top-level subvolume to check
	if ! sudo mount -o subvolid=5 "$device" "$tmpdir" 2>/dev/null; then
		rm -rf "$tmpdir"
		return 1
	fi

	local exists=1
	if [[ -d "$tmpdir/@snapshots" ]]; then
		exists=0
	fi

	sudo umount "$tmpdir"
	rm -rf "$tmpdir"
	return $exists
}

# Create @snapshots subvolume
create_snapshots_subvolume() {
	local device="$1"
	local tmpdir
	tmpdir=$(mktemp -d)

	log_info "Creating @snapshots subvolume..."

	if ! sudo mount -o subvolid=5 "$device" "$tmpdir"; then
		log_error "Failed to mount top-level Btrfs subvolume"
		rm -rf "$tmpdir"
		return 1
	fi

	if ! sudo btrfs subvolume create "$tmpdir/@snapshots"; then
		log_error "Failed to create @snapshots subvolume"
		sudo umount "$tmpdir"
		rm -rf "$tmpdir"
		return 1
	fi

	sudo umount "$tmpdir"
	rm -rf "$tmpdir"

	log_info "@snapshots subvolume created successfully"
	return 0
}

# Add /.snapshots entry to fstab
add_fstab_snapshots_entry() {
	local device="$1"
	local mount_options="$2"

	log_info "Adding /.snapshots entry to /etc/fstab..."

	# Build the fstab line with proper comma-separated options
	local fstab_line="${device}  /.snapshots  btrfs  subvol=@snapshots,${mount_options}  0  0"

	# Backup fstab
	sudo cp /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d%H%M%S)"

	# Append the entry
	echo "" | sudo tee -a /etc/fstab >/dev/null
	echo "# Btrfs snapshots subvolume (added by archway bootstrap)" | sudo tee -a /etc/fstab >/dev/null
	echo "$fstab_line" | sudo tee -a /etc/fstab >/dev/null

	log_info "Added to /etc/fstab: $fstab_line"
	return 0
}

configure_snapper() {
	log_info "Checking for Btrfs snapshot configuration..."

	local root_fstype
	root_fstype=$(findmnt -n -o FSTYPE /)

	if [[ "$root_fstype" != "btrfs" ]]; then
		log_info "Root filesystem is $root_fstype (not Btrfs) - skipping snapper configuration"
		return 0
	fi

	log_info "Btrfs detected on root filesystem"

	if ! command -v snapper >/dev/null 2>&1; then
		log_warn "snapper not installed - skipping snapshot configuration"
		return 0
	fi

	local btrfs_device
	btrfs_device=$(get_btrfs_device)
	log_info "Btrfs device: $btrfs_device"

	local mount_options
	mount_options=$(get_btrfs_mount_options)
	log_info "Mount options: $mount_options"

	# Check if @snapshots subvolume exists, create if not
	if ! check_snapshots_subvolume_exists "$btrfs_device"; then
		log_warn "@snapshots subvolume does not exist"

		if ! create_snapshots_subvolume "$btrfs_device"; then
			log_error "Failed to create @snapshots subvolume automatically"
			print_btrfs_setup_guidance
			return 0
		fi
	else
		log_info "@snapshots subvolume exists"
	fi

	# Check if fstab has /.snapshots entry, add if not
	if ! grep -Eq '^[^#].*[[:space:]]+/.snapshots[[:space:]]+' /etc/fstab 2>/dev/null; then
		log_warn "/etc/fstab has no /.snapshots entry"

		if ! add_fstab_snapshots_entry "$btrfs_device" "$mount_options"; then
			log_error "Failed to add /.snapshots to /etc/fstab automatically"
			print_btrfs_setup_guidance
			return 0
		fi
	else
		log_info "/etc/fstab already has /.snapshots entry"
	fi

	# Ensure /.snapshots mount point exists and is mounted
	if ! findmnt -n /.snapshots >/dev/null 2>&1; then
		log_info "Mounting /.snapshots..."
		sudo mkdir -p /.snapshots
		if ! sudo mount /.snapshots; then
			log_error "Failed to mount /.snapshots"
			print_btrfs_setup_guidance
			return 0
		fi
	fi

	# Now configure snapper
	if sudo snapper -c root list >/dev/null 2>&1; then
		log_info "Snapper 'root' config already exists"
	else
		log_info "Creating snapper config for root..."

		# snapper create-config will create its own .snapshots subvolume
		# We need to work around this by:
		# 1. Backup fstab
		# 2. Unmount our @snapshots
		# 3. Let snapper create-config run
		# 4. Restore fstab
		# 5. Delete snapper's .snapshots subvolume
		# 6. Remount our @snapshots

		local fstab_backup
		fstab_backup=$(mktemp)
		sudo cp /etc/fstab "$fstab_backup"

		sudo umount /.snapshots

		if [[ -d /.snapshots ]]; then
			sudo rmdir /.snapshots 2>/dev/null || true
		fi

		sudo snapper -c root create-config /

		sudo cp "$fstab_backup" /etc/fstab
		sudo rm -f "$fstab_backup"

		# Delete the subvolume snapper created (we use our own @snapshots)
		if sudo btrfs subvolume show /.snapshots >/dev/null 2>&1; then
			sudo btrfs subvolume delete /.snapshots
		fi

		sudo mkdir -p /.snapshots
		if ! sudo mount /.snapshots; then
			log_error "Failed to remount /.snapshots after snapper init"
			log_warn "Run 'sudo mount -a' and re-run bootstrap"
			return 0
		fi

		sudo chmod 750 /.snapshots
	fi

	log_info "Configuring snapper retention policy..."

	sudo snapper -c root set-config "TIMELINE_CREATE=yes"
	sudo snapper -c root set-config "TIMELINE_MIN_AGE=1800"
	sudo snapper -c root set-config "TIMELINE_LIMIT_HOURLY=5"
	sudo snapper -c root set-config "TIMELINE_LIMIT_DAILY=7"
	sudo snapper -c root set-config "TIMELINE_LIMIT_WEEKLY=4"
	sudo snapper -c root set-config "TIMELINE_LIMIT_MONTHLY=2"
	sudo snapper -c root set-config "TIMELINE_LIMIT_YEARLY=0"
	sudo snapper -c root set-config "ALLOW_GROUPS=wheel"

	log_info "Enabling snapper timers..."
	sudo systemctl enable --now snapper-timeline.timer
	sudo systemctl enable --now snapper-cleanup.timer

	if [[ -f /boot/grub/grub.cfg ]] && { [[ -f /usr/lib/systemd/system/grub-btrfsd.service ]] || [[ -f /etc/systemd/system/grub-btrfsd.service ]]; }; then
		log_info "GRUB detected; enabling grub-btrfs daemon..."
		sudo systemctl enable --now grub-btrfsd
	fi

	log_info "Snapper configuration complete"
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
	if [[ -f "/usr/share/wayland-sessions/niri.desktop" ]]; then
		autologin_session="niri"
	elif [[ -f "/usr/share/xsessions/plasma.desktop" ]]; then
		autologin_session="plasma"
	elif [[ -f "/usr/share/wayland-sessions/plasmawayland.desktop" ]]; then
		autologin_session="plasmawayland"
	fi

	if [[ -z "$autologin_session" ]]; then
		log_warn "No known SDDM session found (niri/plasma). Skipping autologin configuration"
		return 0
	fi

	# Skip if running as root without SUDO_USER (can't determine target user)
	if [[ -z "$autologin_user" || "$autologin_user" == "root" ]]; then
		log_warn "Cannot determine autologin user - skipping autologin configuration"
		log_warn "To enable autologin manually, create $autologin_conf with:"
		log_warn "  [Autologin]"
	log_warn "  User=yourusername"
	log_warn "  Session=niri"
		return 0
	fi

	# Check if already configured for this user
	if [[ -f "$autologin_conf" ]] && grep -q "User=$autologin_user" "$autologin_conf" 2>/dev/null; then
		log_info "SDDM autologin already configured for $autologin_user"
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
# MAIN
# =============================================================================

main() {
	log_info "Bootstrap script version: ${SCRIPT_VERSION}"
	log_info "Starting archway bootstrap..."
	log_info "Repository: $REPO_ROOT"

	# Safety reminder about pre-bootstrap snapshot (only if Btrfs detected)
	local root_fstype
	root_fstype=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "unknown")
	if [[ "$root_fstype" == "btrfs" ]] && command -v snapper >/dev/null 2>&1; then
		if ! sudo snapper -c root list 2>/dev/null | grep -q "pre-bootstrap"; then
			log_warn "No pre-bootstrap snapshot found!"
			log_warn "For safety, consider creating one first:"
			log_warn "  sudo ./infra/pre-bootstrap.sh create"
			echo ""
			read -r -p "Continue anyway? [y/N] " response
			if [[ ! "$response" =~ ^[Yy]$ ]]; then
				log_info "Cancelled. Run: sudo ./infra/pre-bootstrap.sh create"
				exit 0
			fi
		fi
	fi

	CURRENT_PHASE="pre-flight checks"
	check_prerequisites

	CURRENT_PHASE="installing yay (AUR helper)"
	install_yay

	CURRENT_PHASE="installing pacman packages"
	install_pacman_packages

	CURRENT_PHASE="installing AUR packages"
	install_aur_packages

	CURRENT_PHASE="enabling systemd services"
	enable_services

	# Configure system settings
	CURRENT_PHASE="configuring PAM for gnome-keyring"
	configure_pam_keyring

	CURRENT_PHASE="configuring PAM for fingerprint auth"
	configure_pam_fingerprint

	CURRENT_PHASE="configuring PAM for DMS lock screen"
	configure_pam_dms

	CURRENT_PHASE="configuring XDG portals"
	configure_portals

	CURRENT_PHASE="configuring polkit"
	configure_polkit

	CURRENT_PHASE="configuring SDDM autologin"
	configure_sddm_autologin

	CURRENT_PHASE="configuring snapper (Btrfs snapshots)"
	configure_snapper

	# User-level setup (skip if running as root)
	if [[ $EUID -ne 0 ]]; then
		CURRENT_PHASE="enabling user systemd services"
		enable_user_services

		CURRENT_PHASE="setting default shell to zsh"
		set_default_shell
	else
		log_warn "Running as root - skipping user service setup and shell change"
		log_warn "Run as regular user to enable: pipewire, wireplumber, portal services"
	fi

	CURRENT_PHASE="complete"
	log_info "Bootstrap complete!"
	log_info ""
	log_info "Next steps:"
	log_info "  1. Reboot to start SDDM (graphical login screen)"
	log_info "  2. Apply dotfiles: ./infra/dotfiles.sh"
	log_info "  3. Install DMS: curl -fsSL https://dms.avenge.cloud | bash"
	log_info "  4. Validate: ./infra/doctor.sh"
}

main "$@"
