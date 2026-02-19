#!/usr/bin/env bash
set -euo pipefail

# Post-DMS install: applies custom DMS configurations
# Run this AFTER dankinstall completes
# Safe to re-run (idempotent)

SCRIPT_VERSION="2026-02-18-1"

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOTS_DIR="${REPO_ROOT}/dots"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

# Error handler
on_error() {
	log_error "Error on line $1: $2 (exit code: $3)"
	exit 1
}
trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR

main() {
	log_info "Applying DMS customizations (v${SCRIPT_VERSION})"
	log_info ""

	# ==========================================================================
	# PRE-FLIGHT CHECKS
	# ==========================================================================
	if ! command -v dms &>/dev/null; then
		log_error "DMS is not installed. Run dankinstall first."
		exit 1
	fi

	if [[ ! -d "${HOME}/.config/DankMaterialShell" ]]; then
		log_error "DMS config directory not found. Run DMS at least once first."
		exit 1
	fi

	# ==========================================================================
	# SETTINGS (theme: auto/neutral, bar auto-hide, etc.)
	# ==========================================================================
	log_info "--- DMS Settings ---"
	if [[ -f "${DOTS_DIR}/DankMaterialShell/settings.json" ]]; then
		cp "${DOTS_DIR}/DankMaterialShell/settings.json" "${HOME}/.config/DankMaterialShell/settings.json"
		log_info "Copied settings.json (theme: scheme-neutral, bar auto-hide: enabled)"
	else
		log_warn "settings.json not found in dots/, skipping"
	fi

	# ==========================================================================
	# KEYBINDS (Mod+Return for terminal)
	# ==========================================================================
	log_info "--- Keybinds ---"
	if [[ -f "${DOTS_DIR}/niri/dms/binds.kdl" ]]; then
		mkdir -p "${HOME}/.config/niri/dms"
		cp "${DOTS_DIR}/niri/dms/binds.kdl" "${HOME}/.config/niri/dms/binds.kdl"
		log_info "Copied binds.kdl (terminal: Mod+Return)"
	else
		log_warn "binds.kdl not found in dots/, skipping"
	fi

	# ==========================================================================
	# WALLPAPER
	# ==========================================================================
	log_info "--- Wallpaper ---"
	local wallpaper_src="${DOTS_DIR}/Wallpaper/wallpaper.png"
	if [[ -f "$wallpaper_src" ]]; then
		# DMS stores wallpaper path internally, set via IPC
		dms ipc call wallpaper set "$wallpaper_src"
		log_info "Set wallpaper: $wallpaper_src"
	else
		log_warn "wallpaper.png not found in dots/Wallpaper/, skipping"
	fi

	log_info ""
	log_info "=========================================="
	log_info "DMS customizations applied!"
	log_info "=========================================="
	log_info ""
	log_info "Note: Restart DMS or log out/in for all changes to take effect."
}

main "$@"
