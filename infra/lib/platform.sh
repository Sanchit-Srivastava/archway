#!/usr/bin/env bash

# Platform detection shared by Linux installers.
# Prints one of: arch, cachyos, macos, unsupported.
detect_platform() {
	if [[ "$(uname -s)" == "Darwin" ]]; then
		printf '%s\n' "macos"
		return 0
	fi

	if [[ ! -r /etc/os-release ]]; then
		printf '%s\n' "unsupported"
		return 0
	fi

	local id=""
	local id_like=""
	# shellcheck disable=SC1091
	. /etc/os-release
	id="${ID:-}"
	id_like="${ID_LIKE:-}"

	case "$id" in
	cachyos) printf '%s\n' "cachyos" ;;
	arch) printf '%s\n' "arch" ;;
	*)
		if [[ " $id_like " == *" arch "* ]]; then
			printf '%s\n' "unsupported"
		else
			printf '%s\n' "unsupported"
		fi
		;;
	esac
}
