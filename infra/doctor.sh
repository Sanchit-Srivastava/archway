#!/usr/bin/env bash
set -euo pipefail

# Doctor script: runtime validation of laptop-critical functionality
# Outputs structured results for automated checking

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

# Colors + log_* are provided by common.sh (BLUE included)

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Output format (human or tap)
FORMAT="${DOCTOR_FORMAT:-human}"

# Filter to run only specific checks (empty means all)
ONLY_CHECK=""

# Check ID mapping for --only filtering and dispatch.
#
# Scope (post-simplification): doctor checks RUNTIME state, CONFIG/symlink DRIFT,
# and BOOT safety — i.e. things `--audit-packages` cannot see. It deliberately
# does NOT re-verify "is package X installed" (bare `command -v` checks): that's
# what `--audit-packages` is for. Litmus test for adding a check: if its only
# fix is "sudo pacman -S X", it belongs in the package audit, not here.
declare -A CHECK_IDS=(
	# Audio / portal runtime (genuinely flake; user-level daemons)
	[pipewire]="check_pipewire_running"
	[wireplumber]="check_wireplumber_running"
	["xdg-portal"]="check_xdg_portal_running"
	# Desktop runtime facts not in any package list
	["polkit-agent"]="check_polkit_agent"
	["secret-service"]="check_secret_service"
	# System service enable-state (cheap is-enabled; genuinely gets left off)
	[networkmanager]="check_network_manager"
	[bluetooth]="check_bluetooth"
	[udisks2]="check_udisks2"
	[polkit]="check_polkit"
	["accounts-daemon"]="check_accounts_daemon"
	[keyd]="check_keyd"
	# Symlink / config drift (clobbered by pacman or stray real files)
	[dotfiles]="check_dotfiles_linked"
	["starship-config"]="check_starship_config"
	["environment-d"]="check_environment_d"
	# Boot safety net
	["boot-entry"]="check_boot_entry"
	# Evidence that the archinstall KDE baseline (the contract) is present
	["display-manager"]="check_display_manager"
)

# Print TAP header
tap_plan() {
	if [[ "$FORMAT" == "tap" ]]; then
		echo "1..$1"
	fi
}

# Print TAP result
tap_result() {
	local status="$1"
	local num="$2"
	local name="$3"
	local message="${4:-}"

	if [[ "$FORMAT" == "tap" ]]; then
		if [[ "$status" == "ok" ]]; then
			echo "ok $num - $name"
		else
			echo "not ok $num - $name"
			if [[ -n "$message" ]]; then
				echo "  ---"
				echo "  message: $message"
				echo "  ..."
			fi
		fi
	fi
}

# Log helpers for human format
log_info() { [[ "$FORMAT" == "human" ]] && printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_pass() { [[ "$FORMAT" == "human" ]] && printf "${GREEN}[PASS]${NC} %s\n" "$1"; }
log_fail() { [[ "$FORMAT" == "human" ]] && printf "${RED}[FAIL]${NC} %s\n" "$1" >&2; }
log_warn() { [[ "$FORMAT" == "human" ]] && printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }

# Run a single check
run_check() {
	local name="$1"
	local command="$2"
	local fix_message="${3:-See docs/ARCHITECTURE.md for fixes}"

	TOTAL_TESTS=$((TOTAL_TESTS + 1))
	local num=$TOTAL_TESTS

	if eval "$command" >/dev/null 2>&1; then
		PASSED_TESTS=$((PASSED_TESTS + 1))
		tap_result "ok" "$num" "$name"
		log_pass "$name"
		return 0
	else
		FAILED_TESTS=$((FAILED_TESTS + 1))
		tap_result "not ok" "$num" "$name" "$fix_message"
		log_fail "$name"
		[[ "$FORMAT" == "human" ]] && log_warn "Fix: $fix_message"
		return 1
	fi
}

# =============================================================================
# INDIVIDUAL CHECKS
# =============================================================================

check_pipewire_running() {
	run_check \
		"PipeWire service active" \
		"systemctl --user is-active pipewire" \
		"Enable PipeWire: systemctl --user enable --now pipewire"
}

check_wireplumber_running() {
	run_check \
		"WirePlumber session manager active" \
		"systemctl --user is-active wireplumber" \
		"Enable WirePlumber: systemctl --user enable --now wireplumber"
}

check_xdg_portal_running() {
	run_check \
		"xdg-desktop-portal service active" \
		"systemctl --user is-active xdg-desktop-portal" \
		"Enable portal: systemctl --user enable --now xdg-desktop-portal"
}

check_polkit_agent() {
	run_check \
		"Polkit agent running" \
		"pgrep -f 'polkit-agent|polkit-kde|polkit-gnome|lxqt-policykit|dms'" \
		"DMS provides polkit agent, or start polkit-gnome manually"
}

check_secret_service() {
	run_check \
		"Secret service responding" \
		"busctl --user list | grep -q 'org.freedesktop.secrets'" \
		"Install and enable gnome-keyring: pacman -S gnome-keyring"
}

check_network_manager() {
	run_check \
		"NetworkManager service enabled" \
		"systemctl is-enabled NetworkManager" \
		"Enable: sudo systemctl enable --now NetworkManager"
}

check_bluetooth() {
	run_check \
		"Bluetooth service enabled" \
		"systemctl is-enabled bluetooth" \
		"Enable: sudo systemctl enable --now bluetooth"
}

check_udisks2() {
	run_check \
		"udisks2 service enabled (removable media)" \
		"systemctl is-enabled udisks2" \
		"Enable: sudo systemctl enable --now udisks2"
}

check_polkit() {
	run_check \
		"polkit service enabled" \
		"systemctl is-enabled polkit" \
		"Enable: sudo systemctl enable --now polkit"
}

check_accounts_daemon() {
	run_check \
		"accounts-daemon service enabled (DMS user info)" \
		"systemctl is-enabled accounts-daemon" \
		"Enable: sudo systemctl enable --now accounts-daemon"
}

check_keyd() {
	run_check \
		"keyd service enabled (keyboard remapping)" \
		"systemctl is-enabled keyd && test -f /etc/keyd/default.conf" \
		"Run bootstrap.sh to install and configure keyd"
}

check_dotfiles_linked() {
	run_check \
		"Dotfiles linked (~/.zshrc)" \
		"test -L ${HOME}/.zshrc" \
		"Run: ./infra/dotfiles.sh"
}

check_starship_config() {
	run_check \
		"Starship config linked" \
		"test -L ${HOME}/.config/starship.toml" \
		"Run: ./infra/dotfiles.sh"
}

check_environment_d() {
	run_check \
		"Environment.d config linked" \
		"test -L ${HOME}/.config/environment.d/50-archway.conf" \
		"Run: ./infra/dotfiles.sh"
}

# Warns BEFORE a vanished-boot-entry bites you: checks that the firmware NVRAM
# still has a systemd-boot entry AND that the removable-media fallback exists on
# the ESP (the fallback boots even if NVRAM is wiped). Especially relevant on
# ThinkPad/Lenovo firmware that prunes boot entries.
check_boot_entry() {
	if [[ ! -d /sys/firmware/efi ]]; then
		run_check "Boot entry present (skipped - not UEFI)" "true" ""
		return 0
	fi

	# Locate ESP (mirror of detect_esp_mount in bootstrap.sh).
	local esp="" mp
	for mp in /efi /boot /boot/efi; do
		if findmnt -n -o FSTYPE "$mp" 2>/dev/null | grep -q '^vfat$'; then
			esp="$mp"
			break
		fi
	done

	# The removable-media fallback is the real safety net (survives NVRAM wipe).
	if [[ -n "$esp" ]]; then
		run_check \
			"Bootloader fallback present (EFI/BOOT/BOOTX64.EFI)" \
			"test -f ${esp}/EFI/BOOT/BOOTX64.EFI" \
			"Removable-media fallback missing. Run: ./infra/fix-boot.sh (re-asserts systemd-boot + fallback so a wiped NVRAM still boots)."
	fi

	# Best-effort NVRAM entry check (informational; needs efibootmgr).
	if command -v efibootmgr >/dev/null 2>&1; then
		run_check \
			"Firmware NVRAM has a boot manager entry" \
			"efibootmgr 2>/dev/null | grep -qiE 'Linux Boot Manager|systemd'" \
			"No systemd-boot NVRAM entry found. Run: ./infra/fix-boot.sh to recreate it. (The EFI/BOOT fallback above will still boot the machine.)"
	fi
}

# Verifies (lightly) that the archinstall KDE Plasma profile baseline is present.
# This is the documented contract: archway layers on top; it does not create the DM/Plasma stack.
check_display_manager() {
	# Accept common DM units enabled by the archinstall KDE profile.
	# The command succeeds (exit 0) if at least one plausible DM is enabled.
	run_check \
		"Display manager enabled (sddm or plasma login manager)" \
		"for u in sddm sddm.service plasmalogin plasmalogin.service; do systemctl is-enabled \"\$u\" >/dev/null 2>&1 && exit 0; done; exit 1" \
		"Expected a display manager (sddm/plasmalogin) from the archinstall KDE profile. Inspect with 'systemctl status sddm' and ensure you selected the KDE desktop profile in archinstall."
}

# =============================================================================
# PACKAGE AUDIT
# =============================================================================

audit_packages() {
	local tmpdir
	tmpdir=$(mktemp -d)

	log_info "Auditing packages: comparing system state to repo lists..."
	echo ""

	# Get explicitly installed packages
	pacman -Qqen | sort >"${tmpdir}/explicit-native.txt"
	pacman -Qqem | sort >"${tmpdir}/explicit-foreign.txt"

	# Build union of all tier package lists.
	# Native: pkgs/{10-base,20-shell,30-desktop,40-extras}.txt
	# Foreign (AUR): pkgs/*.aur.txt
	# Baseline (NOT installed by archway, but expected because the user
	# selected the KDE Plasma desktop profile in archinstall — see
	# docs/SETUP.md §1.7): pkgs/baseline.*.txt — counted only as an
	# allowlist for the "untracked native" check, not as something to install.
	: >"${tmpdir}/repo-native.raw"
	: >"${tmpdir}/repo-foreign.raw"
	: >"${tmpdir}/repo-baseline.raw"
	local f
	for f in "${SCRIPT_DIR}/pkgs"/*.txt; do
		[[ -f "$f" ]] || continue
		case "$(basename "$f")" in
		baseline.*) cat "$f" >>"${tmpdir}/repo-baseline.raw" ;;
		*.aur.txt) cat "$f" >>"${tmpdir}/repo-foreign.raw" ;;
		*) cat "$f" >>"${tmpdir}/repo-native.raw" ;;
		esac
	done
	grep -v '^[[:space:]]*#' "${tmpdir}/repo-native.raw" | grep -v '^[[:space:]]*$' | sort -u >"${tmpdir}/repo-native.txt"
	grep -v '^[[:space:]]*#' "${tmpdir}/repo-foreign.raw" | grep -v '^[[:space:]]*$' | sort -u >"${tmpdir}/repo-foreign.txt"
	grep -v '^[[:space:]]*#' "${tmpdir}/repo-baseline.raw" | grep -v '^[[:space:]]*$' | sort -u >"${tmpdir}/repo-baseline.txt"

	# Allowlist for the audit = repo-native ∪ repo-baseline.
	# (Baseline packages are tolerated as "installed but not driven by archway".)
	sort -u "${tmpdir}/repo-native.txt" "${tmpdir}/repo-baseline.txt" >"${tmpdir}/allowed-native.txt"

	# Compare
	comm -23 "${tmpdir}/explicit-native.txt" "${tmpdir}/allowed-native.txt" >"${tmpdir}/untracked-native.txt"
	comm -23 "${tmpdir}/explicit-foreign.txt" "${tmpdir}/repo-foreign.txt" >"${tmpdir}/untracked-foreign.txt"
	comm -13 "${tmpdir}/explicit-native.txt" "${tmpdir}/repo-native.txt" >"${tmpdir}/missing-native.txt"
	comm -13 "${tmpdir}/explicit-foreign.txt" "${tmpdir}/repo-foreign.txt" >"${tmpdir}/missing-foreign.txt"

	# Count
	local untracked_native_count untracked_foreign_count missing_native_count missing_foreign_count
	untracked_native_count=$(wc -l <"${tmpdir}/untracked-native.txt" | tr -d ' ')
	untracked_foreign_count=$(wc -l <"${tmpdir}/untracked-foreign.txt" | tr -d ' ')
	missing_native_count=$(wc -l <"${tmpdir}/missing-native.txt" | tr -d ' ')
	missing_foreign_count=$(wc -l <"${tmpdir}/missing-foreign.txt" | tr -d ' ')

	# Display
	echo "========================================"
	echo "         PACKAGE AUDIT REPORT"
	echo "========================================"
	echo ""

	if [[ "$untracked_native_count" -gt 0 ]]; then
		printf "%bUntracked native packages (%s):%b\n" "$YELLOW" "$untracked_native_count" "$NC"
		sed 's/^/  - /' "${tmpdir}/untracked-native.txt"
		echo ""
		echo "  Action: Add to a tier file under infra/pkgs/ or remove"
		echo ""
	else
		printf "%bNo untracked native packages%b\n" "$GREEN" "$NC"
	fi

	if [[ "$untracked_foreign_count" -gt 0 ]]; then
		printf "%bUntracked AUR packages (%s):%b\n" "$YELLOW" "$untracked_foreign_count" "$NC"
		sed 's/^/  - /' "${tmpdir}/untracked-foreign.txt"
		echo ""
		echo "  Action: Add to infra/pkgs/40-extras.aur.txt or remove"
		echo ""
	else
		printf "%bNo untracked AUR packages%b\n" "$GREEN" "$NC"
	fi

	if [[ "$missing_native_count" -gt 0 ]]; then
		printf "%bMissing native packages (%s):%b\n" "$YELLOW" "$missing_native_count" "$NC"
		sed 's/^/  - /' "${tmpdir}/missing-native.txt"
		echo ""
		echo "  Action: Run ./infra/bootstrap.sh to install"
		echo ""
	fi

	if [[ "$missing_foreign_count" -gt 0 ]]; then
		printf "%bMissing AUR packages (%s):%b\n" "$YELLOW" "$missing_foreign_count" "$NC"
		sed 's/^/  - /' "${tmpdir}/missing-foreign.txt"
		echo ""
		echo "  Action: Run ./infra/bootstrap.sh to install"
		echo ""
	fi

	# Summary
	local total_untracked=$((untracked_native_count + untracked_foreign_count))
	local total_missing=$((missing_native_count + missing_foreign_count))

	echo "========================================"
	if [[ "$total_untracked" -eq 0 && "$total_missing" -eq 0 ]]; then
		printf "%bSystem is in sync with repository%b\n" "$GREEN" "$NC"
		rm -rf "$tmpdir"
		return 0
	else
		printf "%bFound %s untracked and %s missing packages%b\n" "$YELLOW" "$total_untracked" "$total_missing" "$NC"
		rm -rf "$tmpdir"
		return 1
	fi
}

# =============================================================================
# SUMMARY
# =============================================================================

print_summary() {
	if [[ "$FORMAT" == "human" ]]; then
		echo ""
		echo "========================================"
		echo "           DOCTOR SUMMARY"
		echo "========================================"
		printf "Total checks:  %d\n" "$TOTAL_TESTS"
		printf "${GREEN}Passed:${NC}        %d\n" "$PASSED_TESTS"
		printf "${RED}Failed:${NC}        %d\n" "$FAILED_TESTS"
		echo "========================================"

		if [[ $FAILED_TESTS -eq 0 ]]; then
			echo "All checks passed! System is healthy."
			return 0
		else
			echo "Some checks failed. See messages above for fixes."
			return 1
		fi
	fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--format)
			FORMAT="$2"
			shift 2
			;;
		--format=*)
			FORMAT="${1#*=}"
			shift
			;;
		--list)
			echo "Available checks (use --only <id> to run a single check):"
			echo ""
			# Generated from CHECK_IDS so it can't drift out of sync.
			local id
			for id in $(printf '%s\n' "${!CHECK_IDS[@]}" | sort); do
				printf "  %s\n" "$id"
			done
			echo ""
			echo "Note: doctor checks runtime state, config/symlink drift, and boot"
			echo "safety. To verify packages are installed, use --audit-packages."
			echo ""
			echo "The 'display-manager' check verifies the archinstall KDE baseline contract."
			echo ""
			echo "Other modes:"
			echo "  --audit-packages   Compare installed packages to repo lists"
			exit 0
			;;
		--only)
			ONLY_CHECK="$2"
			if [[ -z "${CHECK_IDS[$ONLY_CHECK]:-}" ]]; then
				echo "error: unknown check id '$ONLY_CHECK'" >&2
				echo "Run --list to see available check IDs" >&2
				exit 1
			fi
			shift 2
			;;
		--only=*)
			ONLY_CHECK="${1#*=}"
			if [[ -z "${CHECK_IDS[$ONLY_CHECK]:-}" ]]; then
				echo "error: unknown check id '$ONLY_CHECK'" >&2
				exit 1
			fi
			shift
			;;
		--audit-packages)
			audit_packages
			exit $?
			;;
		--help | -h)
			echo "Usage: doctor.sh [OPTIONS]"
			echo ""
			echo "Validate runtime state, config drift, and boot safety."
			echo "(For 'is package X installed', use --audit-packages.)"
			echo ""
			echo "Options:"
			echo "  --format FORMAT    Output format: human (default) or tap"
			echo "  --list             List available checks"
			echo "  --only ID          Run only the specified check"
			echo "  --audit-packages   Compare installed packages to repo lists"
			echo "  --help, -h         Show this help"
			exit 0
			;;
		*)
			log_warn "Unknown option: $1"
			shift
			;;
		esac
	done

	# Warn if no graphical session
	if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
		if [[ "$FORMAT" == "human" ]]; then
			log_warn "No graphical session detected. Some checks may fail."
		fi
	fi

	if [[ -n "$ONLY_CHECK" ]]; then
		tap_plan 1
		${CHECK_IDS[$ONLY_CHECK]}
		print_summary
		return
	fi

	tap_plan "${#CHECK_IDS[@]}"

	# Canonical run order. Audio/portal runtime, then desktop runtime facts,
	# then service enable-state, then config/symlink drift, then boot.
	check_pipewire_running
	check_wireplumber_running
	check_xdg_portal_running
	check_polkit_agent
	check_secret_service
	check_network_manager
	check_bluetooth
	check_udisks2
	check_polkit
	check_accounts_daemon
	check_keyd
	check_dotfiles_linked
	check_starship_config
	check_environment_d
	check_display_manager
	check_boot_entry

	print_summary
}

main "$@"
