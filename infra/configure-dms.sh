#!/usr/bin/env bash
set -eEuo pipefail

# Apply portable Archway preferences after DMS has initialized once.

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOTS_DIR="${REPO_ROOT}/dots"
DMS_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/DankMaterialShell"
NIRI_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/niri"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

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

die() {
	log_error "$1"
	exit 1
}

merge_json_overlay() {
	local target="$1"
	local overlay="$2"
	local tmp
	local backup
	[[ -s "$target" ]] || die "DMS has not generated $target yet. Log into niri/DMS once, then rerun."
	[[ -s "$overlay" ]] || die "Preference overlay not found: $overlay"
	jq -e . "$target" >/dev/null || die "Invalid JSON in $target"
	jq -e . "$overlay" >/dev/null || die "Invalid JSON in $overlay"

	tmp="$(mktemp "$(dirname "$target")/.archway-merge.XXXXXX")"
	backup="${target}.pre-archway.bak"
	if [[ ! -e "$backup" ]]; then
		cp "$target" "$backup"
		log_info "Created one-time backup: $backup"
	fi
	if ! jq -s '.[0] * .[1]' "$target" "$overlay" >"$tmp"; then
		rm -f "$tmp"
		die "Failed to merge $overlay into $target"
	fi
	mv "$tmp" "$target"
	log_info "Applied portable preferences to $target"
}

install_plugins() {
	local plugin
	for plugin in "${DMS_PLUGINS[@]}"; do
		if [[ -e "${DMS_DIR}/plugins/${plugin}" ]]; then
			log_info "Plugin already installed: $plugin"
		elif ! dms plugins install "$plugin"; then
			log_warn "Plugin installation failed (continuing): $plugin"
		fi
	done
}

apply_niri_files() {
	[[ -f "${DOTS_DIR}/niri/config.kdl" ]] || die "Missing Archway niri config."
	mkdir -p "${NIRI_DIR}/dms"
	install -m 644 "${DOTS_DIR}/niri/config.kdl" "${NIRI_DIR}/config.kdl"
	install -m 644 "${DOTS_DIR}/niri/dms/binds.kdl" "${NIRI_DIR}/dms/binds.kdl"
	install -m 644 "${DOTS_DIR}/niri/dms/windowrules.kdl" "${NIRI_DIR}/dms/windowrules.kdl"
	log_info "Applied Archway-owned niri configuration."
}

main() {
	command -v dms >/dev/null 2>&1 || die "DMS is not installed. Run 'just dms' first."
	command -v jq >/dev/null 2>&1 || die "jq is required."
	[[ -d "$DMS_DIR" ]] ||
		die "DMS has not initialized $DMS_DIR. Log into niri/DMS once, then rerun."

	apply_niri_files
	merge_json_overlay \
		"${DMS_DIR}/settings.json" \
		"${DOTS_DIR}/DankMaterialShell/preferences.json"

	install_plugins
	if [[ -s "${DMS_DIR}/plugin_settings.json" ]]; then
		merge_json_overlay \
			"${DMS_DIR}/plugin_settings.json" \
			"${DOTS_DIR}/DankMaterialShell/plugin_preferences.json"
	else
		log_warn "DMS has not generated plugin_settings.json; plugin preferences were skipped."
	fi

	if [[ -f "${DOTS_DIR}/Wallpaper/wallpaper.png" ]] &&
		dms ipc call wallpaper set "${DOTS_DIR}/Wallpaper/wallpaper.png"; then
		log_info "Applied Archway wallpaper."
	else
		log_warn "Could not set the wallpaper through DMS IPC."
	fi

	if dms restart; then
		log_info "DMS restarted with Archway preferences."
	else
		log_warn "DMS restart failed. Log out and back into niri to apply all changes."
	fi
}

main "$@"
