#!/usr/bin/env bash
set -euo pipefail

# Install DMS/niri from native repositories and generate upstream defaults.

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# shellcheck source=infra/lib/common.sh
. "${SCRIPT_DIR}/infra/lib/common.sh"

main() {
	[[ $EUID -ne 0 ]] || {
		log_error "Run as a regular user, not root."
		exit 1
	}

	log_info "Installing DMS/niri native packages..."
	"${SCRIPT_DIR}/infra/bootstrap.sh" extras --no-upgrade || {
		log_warn "Some optional extras failed. Attempting DMS setup if the CLI is available."
	}

	if ! command -v dms >/dev/null 2>&1; then
		log_error "DMS is unavailable. Retry with: just extras"
		exit 1
	fi

	log_info "Generating missing DMS compositor defaults..."
	dms setup
	log_info "DMS setup complete."
	log_info "Log out, select niri, and log in once. Then run: just dms-config"
}

main "$@"
