#!/usr/bin/env bash
set -euo pipefail

# Post-DMS install: applies custom DMS configurations
# Run this AFTER dankinstall completes
# Safe to re-run (idempotent)

SCRIPT_VERSION="2026-03-12-1"

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

# DMS plugins to install (plugin IDs from the DMS plugin registry)
DMS_PLUGINS=(
	commandRunner
	dankBatteryAlerts
	dankGifSearch
	dankKDEConnect
	dankPomodoroTimer
	dankStickerSearch
	dmsSessionizer
	niriWindows
	qcalCalendar
	sshConnections
	timeUntil
	webSearch
)

install_plugins() {
	log_info "--- DMS Plugins ---"
	local installed_count=0
	local skipped_count=0

	for plugin in "${DMS_PLUGINS[@]}"; do
		if [[ -d "${HOME}/.config/DankMaterialShell/plugins/${plugin}" ]]; then
			skipped_count=$((skipped_count + 1))
		else
			log_info "Installing plugin: ${plugin}"
			if dms plugins install "$plugin"; then
				installed_count=$((installed_count + 1))
			else
				log_warn "Failed to install plugin: ${plugin} (continuing)"
			fi
		fi
	done

	log_info "Plugins: ${installed_count} installed, ${skipped_count} already present"
}

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
	# NIRI CONFIG (window rules, animations, input, layout, etc.)
	# ==========================================================================
	log_info "--- Niri Config ---"
	if [[ -f "${DOTS_DIR}/niri/config.kdl" ]]; then
		mkdir -p "${HOME}/.config/niri"
		cp "${DOTS_DIR}/niri/config.kdl" "${HOME}/.config/niri/config.kdl"
		log_info "Copied config.kdl (window rules, animations, input, layout)"
	else
		log_warn "config.kdl not found in dots/niri/, skipping"
	fi

	# ==========================================================================
	# DMS-MANAGED NIRI FILES (keybinds, window rules)
	# ==========================================================================
	log_info "--- DMS Niri Files ---"
	mkdir -p "${HOME}/.config/niri/dms"

	if [[ -f "${DOTS_DIR}/niri/dms/binds.kdl" ]]; then
		cp "${DOTS_DIR}/niri/dms/binds.kdl" "${HOME}/.config/niri/dms/binds.kdl"
		log_info "Copied binds.kdl (keybindings)"
	else
		log_warn "binds.kdl not found in dots/, skipping"
	fi

	if [[ -f "${DOTS_DIR}/niri/dms/windowrules.kdl" ]]; then
		cp "${DOTS_DIR}/niri/dms/windowrules.kdl" "${HOME}/.config/niri/dms/windowrules.kdl"
		log_info "Copied windowrules.kdl (Alacritty floating+opacity, Zen maximized)"
	else
		log_warn "windowrules.kdl not found in dots/, skipping"
	fi

	# ==========================================================================
	# SETTINGS (theme, bar layout, matugen templates, power, lock screen, etc.)
	# ==========================================================================
	log_info "--- DMS Settings ---"
	if [[ -f "${DOTS_DIR}/DankMaterialShell/settings.json" ]]; then
		cp "${DOTS_DIR}/DankMaterialShell/settings.json" "${HOME}/.config/DankMaterialShell/settings.json"
		log_info "Copied settings.json (theme: purple, bar: auto-hide, animations: instant)"
	else
		log_warn "settings.json not found in dots/, skipping"
	fi

	# ==========================================================================
	# PLUGINS (install from registry, then apply settings)
	# ==========================================================================
	install_plugins

	log_info "--- Plugin Settings ---"
	if [[ -f "${DOTS_DIR}/DankMaterialShell/plugin_settings.json" ]]; then
		cp "${DOTS_DIR}/DankMaterialShell/plugin_settings.json" "${HOME}/.config/DankMaterialShell/plugin_settings.json"
		log_info "Copied plugin_settings.json (triggers, terminals, enabled states)"
	else
		log_warn "plugin_settings.json not found in dots/, skipping"
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
