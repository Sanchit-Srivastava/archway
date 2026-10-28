#!/usr/bin/env bash
set -eEuo pipefail

# Canonical Archway installer. The normal path runs from an already working
# Niri+DMS session; the minimal path leaves the base desktop alone.

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# shellcheck source=infra/lib/common.sh
. "${SCRIPT_DIR}/infra/lib/common.sh"
# shellcheck source=infra/lib/platform.sh
. "${SCRIPT_DIR}/infra/lib/platform.sh"
# shellcheck source=infra/lib/dms.sh
. "${SCRIPT_DIR}/infra/lib/dms.sh"

SCRIPT_VERSION="2026-10-27-1"

die() {
	log_error "$1"
	exit 1
}

usage() {
	cat <<EOF
Archway installer v${SCRIPT_VERSION}

Usage:
  ./install.sh [install]
  ./install.sh minimal
  ./install.sh secrets
  ./install.sh dms-config

Commands:
  install      Configure an existing Niri+DMS base (default)
  minimal      Core + dotfiles + secrets; leave the base desktop untouched
  secrets      Onboard/validate the age key and decrypt secret targets
  dms-config   Reapply portable preferences to an active Niri+DMS session
EOF
}

ensure_interactive() {
	if [[ ! -t 0 ]]; then
		[[ -c /dev/tty ]] || die "An interactive terminal is required."
		exec </dev/tty
	fi
}

ensure_supported_platform() {
	local platform
	platform="$(detect_platform)"
	case "$platform" in
	arch | cachyos) ;;
	*) die "This installer supports Arch Linux and CachyOS (detected: $platform)." ;;
	esac
}

ensure_desktop_baseline() {
	command -v nmcli >/dev/null 2>&1 ||
		die "NetworkManager is missing. Select it in the OS installer before deploying Archway."
	command -v wpctl >/dev/null 2>&1 ||
		die "WirePlumber/PipeWire is missing. Select PipeWire in the OS installer before deploying Archway."
	if ! systemctl is-active NetworkManager.service >/dev/null 2>&1; then
		die "NetworkManager is not active. Repair the base OS network configuration before deploying Archway."
	fi
}

validate_display_manager() {
	local unit_path
	local unit

	# Check the persistent boot selection, not merely a running login process.
	# readlink -e rejects dangling links after a package removal or upgrade.
	unit_path="$(readlink -e /etc/systemd/system/display-manager.service)" ||
		die "No installed display manager is selected for boot. Enable your chosen login manager before running the full installer; Archway will not select one."
	unit="${unit_path##*/}"
	[[ -f "$unit_path" && "$unit" == *.service ]] ||
		die "The display-manager.service target is invalid or masked. Repair your chosen login manager before deploying Archway."
	[[ "$(systemctl show "$unit" --property=LoadState --value)" == loaded ]] ||
		die "$unit is not loaded. Repair your chosen login manager before deploying Archway."
	systemctl is-active "$unit" >/dev/null 2>&1 ||
		die "$unit is not active. Log in through your chosen login manager before running the full installer."
	log_info "Keeping the existing display manager: $unit"
}

ensure_active_niri_dms_session() {
	local dms_dir
	# Resolve again after upgrades: DMS 2.0 migrates the directory on launch.
	dms_dir="$(dms_config_dir)"
	command -v niri >/dev/null 2>&1 ||
		die "niri is missing. Install Niri through the base OS or upstream Dux Installer first (docs/DMS.md)."
	command -v dms >/dev/null 2>&1 ||
		die "DMS is missing. Use the upstream Dux Installer first; see docs/INSTALL-ARCH.md for current archinstall profile caveats."
	niri validate -c "${REPO_ROOT}/dots/niri/config.kdl" ||
		die "The installed niri cannot validate Archway's configuration. Use niri 26.04 or newer and resolve the errors above before applying preferences."
	[[ -d "$dms_dir" ]] ||
		die "DMS has not initialized $dms_dir. Log into Niri+DMS once before applying Archway preferences."
	systemctl --user is-active niri.service >/dev/null 2>&1 ||
		die "niri.service is not active. Run this command from an active Niri+DMS session."
	systemctl --user is-active dms.service >/dev/null 2>&1 ||
		die "dms.service is not active. Repair the Niri+DMS session before applying Archway preferences."
}

ensure_niri_dms_baseline() {
	ensure_active_niri_dms_session
	validate_display_manager
}

install_core_and_dotfiles() {
	log_info "Installing the reliable Archway core..."
	"${REPO_ROOT}/infra/bootstrap.sh" core

	log_info "Applying ordinary dotfiles..."
	"${REPO_ROOT}/infra/dotfiles.sh"

	log_info "Setting up encrypted secrets..."
	"${REPO_ROOT}/infra/secrets.sh" --prompt
}

secrets_ready() {
	if "${REPO_ROOT}/infra/secrets.sh" --check; then
		return 0
	fi
	log_warn "Archway configuration is complete, but secrets remain pending."
	log_warn "Run 'just secrets' after retrieving the age key."
	return 1
}

run_dms_config() {
	ensure_supported_platform
	[[ $EUID -ne 0 ]] || die "Run as a regular user, not root."
	ensure_desktop_baseline
	ensure_active_niri_dms_session
	"${REPO_ROOT}/infra/configure-dms.sh"
}

run_install() {
	ensure_interactive
	ensure_supported_platform
	[[ $EUID -ne 0 ]] || die "Run as a regular user, not root."
	ensure_desktop_baseline
	ensure_niri_dms_baseline

	install_core_and_dotfiles

	# Core performs a full package upgrade. Revalidate the distro-owned desktop
	# and selected display manager afterward, before applying DMS preferences.
	ensure_desktop_baseline
	ensure_niri_dms_baseline

	if ! "${REPO_ROOT}/infra/bootstrap.sh" extras --no-upgrade; then
		log_warn "Some optional applications failed. The core and DMS configuration can continue."
	fi

	run_dms_config
	secrets_ready || true
	log_info "Archway installation is complete. No intermediate reboot or finish phase is required."
}

run_minimal() {
	ensure_interactive
	ensure_supported_platform
	[[ $EUID -ne 0 ]] || die "Run as a regular user, not root."
	ensure_desktop_baseline
	install_core_and_dotfiles
	ensure_desktop_baseline
	secrets_ready || true
	log_info "Minimal Archway installation is complete. The base desktop was not modified."
}

run_secrets() {
	ensure_interactive
	"${REPO_ROOT}/infra/secrets.sh" --prompt
}

main() {
	local command="install"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		install | minimal | secrets | dms-config) command="$1" ;;
		-h | --help)
			usage
			return 0
			;;
		*)
			log_error "Unknown argument: $1"
			usage
			return 1
			;;
		esac
		shift
	done

	case "$command" in
	install) run_install ;;
	minimal) run_minimal ;;
	secrets) run_secrets ;;
	dms-config) run_dms_config ;;
	esac
}

main "$@"
