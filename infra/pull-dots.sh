#!/usr/bin/env bash
set -euo pipefail

# Pull selected live niri configs back into the repo.
# DMS runtime JSON is deliberately excluded because it is generated,
# versioned, and may contain machine-specific identifiers.
#
# Safe to re-run (idempotent).

SCRIPT_VERSION="2026-03-13-1"

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOTS_DIR="${REPO_ROOT}/dots"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

# log_* + colors from lib/common.sh

# Error handler
on_error() {
	log_error "Error on line $1: $2 (exit code: $3)"
	exit 1
}
trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR

# Pull a single config file from live location into the repo.
# Skips if the live file doesn't exist or is identical to the repo copy.
# Usage: pull_file <live_path> <repo_path>
pull_file() {
	local live="$1"
	local repo="$2"

	if [[ ! -f "$live" ]]; then
		log_warn "Live file not found, skipping: $live"
		return 0
	fi

	mkdir -p "$(dirname "$repo")"

	if [[ -f "$repo" ]] && diff -q "$live" "$repo" &>/dev/null; then
		log_info "Already in sync: $(basename "$repo")"
		return 0
	fi

	cp "$live" "$repo"
	log_info "Pulled: $live -> $repo"
}

main() {
	log_info "Pulling live DMS/niri configs into repo (v${SCRIPT_VERSION})"
	log_info ""

	# Niri main config
	pull_file "${HOME}/.config/niri/config.kdl" \
		"${DOTS_DIR}/niri/config.kdl"

	# DMS-managed niri files
	pull_file "${HOME}/.config/niri/dms/binds.kdl" \
		"${DOTS_DIR}/niri/dms/binds.kdl"

	pull_file "${HOME}/.config/niri/dms/windowrules.kdl" \
		"${DOTS_DIR}/niri/dms/windowrules.kdl"

	# DMS settings
	log_info "DMS runtime JSON is intentionally not imported."
	log_info "Edit the portable overlays in dots/DankMaterialShell/ instead."

	log_info ""
	log_info "Done. Run 'git diff' to review changes before committing."
}

main "$@"
