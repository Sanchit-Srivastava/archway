#!/usr/bin/env bash
set -eEuo pipefail

# Canonical Archway installer. The normal path runs from an already working
# archinstall Niri+DMS session; the minimal path leaves the base desktop alone.

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
DMS_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/DankMaterialShell"

# shellcheck source=infra/lib/common.sh
. "${SCRIPT_DIR}/infra/lib/common.sh"
# shellcheck source=infra/lib/platform.sh
. "${SCRIPT_DIR}/infra/lib/platform.sh"

SCRIPT_VERSION="2026-08-08-3"

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
  install      Configure an existing archinstall Niri+DMS base (default)
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

validate_greetd_command() {
	local config="/etc/greetd/config.toml"
	local command_line=""
	local token=""
	local wrapper=""
	local command_parts=()

	systemctl is-enabled greetd.service >/dev/null 2>&1 ||
		die "greetd is not enabled. Install Arch with archinstall's Niri + DankMaterialShell profile before running the normal installer."
	[[ -r "$config" ]] ||
		die "Cannot read $config. Repair the archinstall Niri+DMS base before deploying Archway."

	command_line="$(sed -n '/^[[:space:]]*\[default_session\][[:space:]]*$/,/^[[:space:]]*\[/s/^[[:space:]]*command[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$config" | sed -n '1p')"
	[[ -n "$command_line" ]] || die "No greetd default-session command was found in $config."
	[[ "$command_line" == *dms-greeter* ]] ||
		die "greetd is not configured for the DMS greeter. Archway will not replace the display manager selected by the OS installer."

	read -r -a command_parts <<<"$command_line"
	for token in "${command_parts[@]}"; do
		token="${token#\"}"
		token="${token%\"}"
		if [[ "$token" == /*dms-greeter* ]]; then
			wrapper="$token"
			break
		fi
	done
	[[ -n "$wrapper" ]] || die "Could not resolve the DMS greeter executable from $config."
	[[ -x "$wrapper" ]] ||
		die "greetd points to missing or non-executable $wrapper. Repair the OS-provided DMS greeter before rebooting; Archway will not rewrite it."
}

ensure_active_niri_dms_session() {
	command -v niri >/dev/null 2>&1 ||
		die "niri is missing. Install Niri through the base OS or upstream DMS installer first."
	command -v dms >/dev/null 2>&1 ||
		die "DMS is missing. Install it through archinstall's Niri+DMS profile or the upstream DMS installer first."
	[[ -d "$DMS_DIR" ]] ||
		die "DMS has not initialized $DMS_DIR. Log into Niri+DMS once before applying Archway preferences."
	systemctl --user is-active niri.service >/dev/null 2>&1 ||
		die "niri.service is not active. Run this command from an active Niri+DMS session."
	systemctl --user is-active dms.service >/dev/null 2>&1 ||
		die "dms.service is not active. Repair the Niri+DMS session before applying Archway preferences."
}

ensure_archinstall_niri_dms_baseline() {
	ensure_active_niri_dms_session
	validate_greetd_command
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
	ensure_archinstall_niri_dms_baseline

	install_core_and_dotfiles

	# Core performs a full package upgrade. Revalidate the distro-owned desktop
	# and greeter afterward, before applying any user configuration.
	ensure_desktop_baseline
	ensure_archinstall_niri_dms_baseline

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
