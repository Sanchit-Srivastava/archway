#!/usr/bin/env bash
set -eEuo pipefail

# Canonical Archway installer. There is no automatic resume: installation and
# post-first-login DMS configuration are explicit, independently retryable.

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
STATE_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/archway"
PENDING_FILE="${STATE_DIR}/dms-config.pending"

# shellcheck source=infra/lib/common.sh
. "${SCRIPT_DIR}/infra/lib/common.sh"
# shellcheck source=infra/lib/platform.sh
. "${SCRIPT_DIR}/infra/lib/platform.sh"

SCRIPT_VERSION="2026-07-29-1"

die() {
	log_error "$1"
	exit 1
}

usage() {
	cat <<EOF
Archway installer v${SCRIPT_VERSION}

Usage:
  ./install.sh [install] [--safe] [--no-reboot]
  ./install.sh finish
  ./install.sh secrets
  ./install.sh dms
  ./install.sh dms-config

Commands:
  install      Core + dotfiles + secrets prompt + optional DMS/extras (default)
  finish       Apply secrets and DMS preferences after the first niri login
  secrets      Onboard/validate the age key and decrypt secret targets
  dms          Install/retry DMS and generate upstream compositor defaults
  dms-config   Apply portable preferences after DMS has initialized once

Options:
  --safe       Install core, dotfiles, and secrets only; skip DMS/AUR extras
  --no-reboot  Do not offer to reboot at the end
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

enable_repo_user_services() {
	systemctl --user daemon-reload
	if [[ ! -s "${XDG_CONFIG_HOME:-${HOME}/.config}/vdirsyncer/config" ]]; then
		if systemctl --user is-enabled vdirsyncer.timer >/dev/null 2>&1; then
			systemctl --user disable --now vdirsyncer.timer
			log_warn "Vdirsyncer is not configured; disabled vdirsyncer.timer."
		else
			log_warn "Vdirsyncer is not configured; leaving vdirsyncer.timer disabled."
		fi
		return 0
	fi
	if systemctl --user is-enabled vdirsyncer.timer >/dev/null 2>&1; then
		log_info "User service already enabled: vdirsyncer.timer"
	else
		systemctl --user enable vdirsyncer.timer
		log_info "Enabled user service: vdirsyncer.timer"
	fi
}

install_core_and_dotfiles() {
	log_info "Installing the reliable Archway core..."
	"${REPO_ROOT}/infra/bootstrap.sh" core

	log_info "Applying ordinary dotfiles..."
	"${REPO_ROOT}/infra/dotfiles.sh"
	enable_repo_user_services

	log_info "Setting up encrypted secrets..."
	"${REPO_ROOT}/infra/secrets.sh" --prompt
}

install_dms() {
	"${REPO_ROOT}/install-dms.sh"
	mkdir -p "$STATE_DIR"
	cat >"$PENDING_FILE" <<EOF
ARCHWAY_DMS_CONFIG_PENDING_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ARCHWAY_REPO_ROOT="${REPO_ROOT}"
EOF
}

run_install() {
	local safe="$1"
	local no_reboot="$2"
	ensure_interactive
	ensure_supported_platform
	[[ $EUID -ne 0 ]] || die "Run as a regular user, not root."

	install_core_and_dotfiles

	if [[ "$safe" -eq 1 ]]; then
		log_info "Safe installation complete. DMS and optional extras were skipped."
		log_info "Install them later with: just dms"
		return 0
	fi

	if ! install_dms; then
		log_warn "DMS/extras did not complete, but the Archway core is ready."
		log_warn "KDE remains fully usable. Retry later with: just dms"
		return 0
	fi

	log_info ""
	log_info "Stage 1 complete."
	log_info "After reboot:"
	log_info "  1. Select niri in the login manager."
	log_info "  2. Log in once and confirm DMS starts with the niri session."
	log_info "  3. Open a terminal and run: cd ${REPO_ROOT} && just finish"

	if [[ "$no_reboot" -eq 0 ]]; then
		local answer=""
		IFS= read -r -p "Reboot now? [Y/n] " answer
		if [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]; then
			sudo reboot
		fi
	fi
}

run_secrets() {
	ensure_interactive
	"${REPO_ROOT}/infra/secrets.sh" --prompt
	enable_repo_user_services
}

run_dms_config() {
	"${REPO_ROOT}/infra/configure-dms.sh"
	rm -f "$PENDING_FILE"
}

run_finish() {
	ensure_interactive
	run_secrets
	local secrets_ready=1
	if ! "${REPO_ROOT}/infra/secrets.sh" --check; then
		secrets_ready=0
	fi
	run_dms_config
	if [[ "$secrets_ready" -eq 1 ]]; then
		log_info "Archway installation is complete."
	else
		log_warn "DMS configuration is complete, but secrets remain pending."
		log_warn "Run 'just secrets' after retrieving the age key."
	fi
}

main() {
	local command="install"
	local safe=0
	local no_reboot=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
		install | finish | secrets | dms | dms-config) command="$1" ;;
		safe | --safe) safe=1 ;;
		--no-reboot) no_reboot=1 ;;
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
	install) run_install "$safe" "$no_reboot" ;;
	finish) run_finish ;;
	secrets) run_secrets ;;
	dms) install_dms ;;
	dms-config) run_dms_config ;;
	esac
}

main "$@"
