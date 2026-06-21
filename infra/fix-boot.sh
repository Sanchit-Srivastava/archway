#!/usr/bin/env bash
set -eEuo pipefail

# fix-boot.sh — idempotent systemd-boot re-assertion / recovery
#
# WHY THIS EXISTS:
#   On some firmware (notably ThinkPad/Lenovo), the UEFI NVRAM boot entries can
#   be wiped, reordered, or pruned — e.g. after a firmware update, CMOS/battery
#   event, or the firmware deciding an entry is "invalid". Symptom: on reboot
#   the machine drops straight to the BIOS/firmware screen and the Arch entry
#   is simply gone.
#
#   This does NOT mean the install is broken. The on-disk system is fine; only
#   the firmware's pointer to the bootloader is missing. The correct fix is to
#   re-run `bootctl install` (re-writes systemd-boot to the ESP AND recreates
#   the NVRAM entry + removable-media fallback) — a ~30-second operation. A full
#   OS reinstall is never required for this.
#
# TWO WAYS TO RUN IT:
#   1. From the running system (preventive / after a scare):
#          ./infra/fix-boot.sh
#   2. From the Arch ISO when the machine won't boot at all:
#          - boot the Arch install USB
#          - unlock + mount your root and ESP, then arch-chroot, e.g.:
#                cryptsetup open /dev/nvmeXnYpZ root
#                mount /dev/mapper/root /mnt
#                mount /dev/nvmeXnYpW /mnt/boot      # your ESP
#                arch-chroot /mnt
#          - then: /root/archway/infra/fix-boot.sh   (or wherever the repo is)
#
# SAFE TO RE-RUN. It only writes the bootloader + a default loader.conf; it
# never touches your kernels, root filesystem, or user data.
#
# Usage:
#   ./infra/fix-boot.sh            # detect ESP, reinstall systemd-boot, verify
#   ./infra/fix-boot.sh --dry-run  # show what it would do
#   ./infra/fix-boot.sh --esp /boot

SCRIPT_VERSION="2026-06-21-1"

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
	exit 1
}

on_error() {
	local line="$1" cmd="$2" code="$3"
	echo "" >&2
	printf "%s[FATAL]%s fix-boot failed during: %s\n" "${RED}${BOLD}" "${NC}" "${CURRENT_PHASE}" >&2
	log_fatal "Exit code: ${code}  (line ${line}: ${cmd})"
}
trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR

DRY_RUN=0
ESP_OVERRIDE=""

usage() {
	cat <<EOF
fix-boot.sh (v${SCRIPT_VERSION})

Re-assert systemd-boot on the ESP and recreate the firmware boot entry.
Recovers from a vanished/wiped UEFI boot entry without reinstalling the OS.

Usage:
  ./infra/fix-boot.sh [options]

Options:
  --esp <path>   ESP mount point (default: autodetect /efi, /boot, /boot/efi).
  --dry-run      Show what would be done without changing anything.
  -h, --help     Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--esp)
		ESP_OVERRIDE="${2:?--esp needs a path}"
		shift 2
		;;
	--esp=*)
		ESP_OVERRIDE="${1#*=}"
		shift
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		log_error "Unknown option: $1"
		usage
		exit 1
		;;
	esac
done

# SUDO: empty when already root (e.g. inside arch-chroot), else "sudo".
SUDO=""
if [[ $EUID -ne 0 ]]; then
	SUDO="sudo"
fi

run_priv() {
	if [[ "$DRY_RUN" -eq 1 ]]; then
		printf "  ${YELLOW}[dry-run]${NC} %s %s\n" "$SUDO" "$*"
		return 0
	fi
	# shellcheck disable=SC2086 # intentional: $SUDO is "" or "sudo"
	$SUDO "$@"
}

# =============================================================================
# DETECT ESP
# =============================================================================
detect_esp() {
	CURRENT_PHASE="detecting ESP"
	if [[ -n "$ESP_OVERRIDE" ]]; then
		[[ -d "$ESP_OVERRIDE" ]] || die "Given --esp '$ESP_OVERRIDE' is not a directory."
		echo "$ESP_OVERRIDE"
		return 0
	fi
	local mp
	for mp in /efi /boot /boot/efi; do
		if findmnt -n -o FSTYPE "$mp" 2>/dev/null | grep -q '^vfat$'; then
			echo "$mp"
			return 0
		fi
	done
	die "No vfat ESP mounted at /efi, /boot, or /boot/efi.
If recovering from the Arch ISO, mount your ESP there first, e.g.:
    mount /dev/your-esp-partition /boot
then re-run this script (use --esp if it's elsewhere)."
}

# =============================================================================
# PRE-FLIGHT
# =============================================================================
preflight() {
	CURRENT_PHASE="pre-flight checks"
	log_info "fix-boot.sh version ${SCRIPT_VERSION}"

	if [[ ! -d /sys/firmware/efi ]]; then
		die "Not booted in UEFI mode (no /sys/firmware/efi).
systemd-boot requires UEFI. If you're on the Arch ISO, reboot it in UEFI mode."
	fi

	command -v bootctl >/dev/null 2>&1 || die "bootctl not found (expected from systemd)."

	if [[ "$DRY_RUN" -eq 0 && -n "$SUDO" ]] && ! sudo -n true 2>/dev/null; then
		log_warn "Sudo password required"
		sudo -v
	fi
}

# =============================================================================
# MAIN WORK
# =============================================================================
main() {
	preflight

	local esp
	esp="$(detect_esp)"
	log_info "Using ESP: $esp"

	# Show current state for the record.
	CURRENT_PHASE="inspecting current boot state"
	log_info "Current firmware boot entries (efibootmgr):"
	if command -v efibootmgr >/dev/null 2>&1; then
		run_priv efibootmgr || true
	else
		log_warn "efibootmgr not installed; cannot show/inspect NVRAM entries."
		log_warn "Install with: ${SUDO:+sudo }pacman -S efibootmgr"
	fi

	# Re-install systemd-boot. This:
	#   - writes EFI/systemd/systemd-bootx64.efi to the ESP
	#   - writes the removable-media fallback EFI/BOOT/BOOTX64.EFI (survives a
	#     wiped NVRAM because firmware always tries it)
	#   - creates/updates the "Linux Boot Manager" NVRAM entry
	CURRENT_PHASE="installing systemd-boot to ESP"
	log_info "Running: bootctl --esp-path=$esp install"
	if ! run_priv bootctl --esp-path="$esp" install; then
		die "bootctl install failed. Inspect output above.
If on the ISO, double-check the ESP is the real EFI partition and is mounted rw."
	fi

	# Ensure a sane default loader.conf (matches bootstrap.sh behavior). Only
	# writes if missing/empty so we never clobber a customized one.
	CURRENT_PHASE="ensuring loader.conf"
	local conf="${esp}/loader/loader.conf"
	if [[ -s "$conf" ]] && grep -qE '^[[:space:]]*default[[:space:]]' "$conf"; then
		log_info "loader.conf already configured ($conf)"
	else
		log_info "Writing default loader.conf to $conf"
		if [[ "$DRY_RUN" -eq 0 ]]; then
			run_priv mkdir -p "${esp}/loader"
			printf '%s\n' \
				"# Managed by archway fix-boot.sh" \
				"# Auto-selects the newest discovered UKI (Type #2 entry)." \
				"default  arch-linux*.efi" \
				"timeout  3" \
				"console-mode max" \
				"editor   no" | $SUDO tee "$conf" >/dev/null
			run_priv chmod 644 "$conf"
		fi
	fi

	# Verify a bootable entry exists (Type #1 .conf OR Type #2 UKI).
	CURRENT_PHASE="verifying bootable entry"
	if compgen -G "${esp}/loader/entries/*.conf" >/dev/null ||
		compgen -G "${esp}/EFI/Linux/*.efi" >/dev/null; then
		log_info "Bootable entry present (loader/entries/*.conf or EFI/Linux/*.efi)."
	else
		log_warn "No bootable entry found in $esp!"
		log_warn "  Expected: ${esp}/EFI/Linux/*.efi (UKI) or ${esp}/loader/entries/*.conf"
		log_warn "  Your kernels may not have generated a UKI. Try: ${SUDO:+sudo }mkinitcpio -P"
	fi

	echo ""
	CURRENT_PHASE="final report"
	log_info "Updated firmware boot entries:"
	if command -v efibootmgr >/dev/null 2>&1; then
		run_priv efibootmgr || true
	fi
	run_priv bootctl --esp-path="$esp" status 2>/dev/null | head -20 || true

	echo ""
	log_info "═══════════════════════════════════════════════════════════════════"
	log_info "Boot recovery complete."
	log_info "═══════════════════════════════════════════════════════════════════"
	log_info "If you ran this from the Arch ISO: exit the chroot and reboot:"
	log_info "    exit; umount -R /mnt; reboot"
	log_info ""
	log_info "TIP (ThinkPad/Lenovo): in firmware setup, ensure 'OS Optimized"
	log_info "Defaults' is on and the 'Linux Boot Manager' entry is enabled and"
	log_info "first in the UEFI boot order. The EFI/BOOT/BOOTX64.EFI fallback"
	log_info "this script wrote will boot even if NVRAM is wiped again."
}

main "$@"
