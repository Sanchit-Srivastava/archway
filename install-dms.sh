#!/usr/bin/env bash
set -euo pipefail

# Install DMS/niri from native repositories and generate upstream defaults.

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
NIRI_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/niri"

# shellcheck source=infra/lib/common.sh
. "${SCRIPT_DIR}/infra/lib/common.sh"

configure_niri_session() {
	local dots_dir="${SCRIPT_DIR}/dots"

	systemctl --user daemon-reload
	systemctl --user add-wants niri.service dms.service

	mkdir -p "${NIRI_DIR}/dms"
	install -m 644 "${dots_dir}/niri/config.kdl" "${NIRI_DIR}/config.kdl"
	install -m 644 "${dots_dir}/niri/dms/binds.kdl" "${NIRI_DIR}/dms/binds.kdl"
	install -m 644 "${dots_dir}/niri/dms/windowrules.kdl" "${NIRI_DIR}/dms/windowrules.kdl"
	log_info "Bound DMS to the niri systemd session and applied Archway's niri configuration."
}

main() {
	[[ $EUID -ne 0 ]] || {
		log_error "Run as a regular user, not root."
		exit 1
	}

	log_info "Installing DMS/niri native packages..."
	"${SCRIPT_DIR}/infra/bootstrap.sh" dms --no-upgrade

	if ! command -v dms >/dev/null 2>&1; then
		log_error "DMS is unavailable. Retry with: just dms"
		exit 1
	fi

	log_info "Generating missing DMS compositor defaults..."
	log_info "Choose niri and systemd integration when prompted."
	dms setup
	configure_niri_session
	log_info "DMS setup complete."
	log_info "Log out, select niri, and log in once. Then run: just dms-config"
}

main "$@"
