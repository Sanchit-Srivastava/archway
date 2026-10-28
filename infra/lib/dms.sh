#!/usr/bin/env bash
# Read-only discovery; DMS itself owns migration and compatibility symlinks.

dms_config_dir() {
	local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
	if [[ -d "${config_home}/dms" ]]; then
		printf '%s\n' "${config_home}/dms"
	elif [[ -d "${config_home}/DankMaterialShell" ]]; then
		printf '%s\n' "${config_home}/DankMaterialShell"
	else
		printf '%s\n' "${config_home}/dms"
	fi
}
