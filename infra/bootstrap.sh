#!/usr/bin/env bash
set -eEuo pipefail

# Archway Linux package/configuration engine.
# The base distro owns boot, filesystems, GPU drivers, mirrors, repositories,
# the base graphical profile, display manager, networking, audio, and power
# management.

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/platform.sh
. "${SCRIPT_DIR}/lib/platform.sh"

SCRIPT_VERSION="2026-08-08-3"
CURRENT_PHASE="initialization"
BOOTSTRAP_STARTED=0

die() {
	log_fatal "$1"
	log_fatal "Phase: ${CURRENT_PHASE}"
	log_fatal "Fix the error and rerun the same command."
	exit 1
}

on_error() {
	local line="$1"
	local cmd="$2"
	local code="$3"
	log_fatal "Bootstrap failed during: ${CURRENT_PHASE}"
	log_fatal "Exit ${code}, line ${line}: ${cmd}"
}

on_exit() {
	local code="$1"
	[[ "$BOOTSTRAP_STARTED" -eq 1 ]] || return 0
	if [[ "$code" -eq 0 ]]; then
		log_info "Bootstrap operation completed."
	else
		log_warn "Bootstrap operation exited with code $code."
	fi
}

trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR
trap 'on_exit "$?"' EXIT

usage() {
	cat <<EOF
Usage: $(basename "$0") [core|extras] [--no-upgrade]

  core       Install reliable native packages and Archway-owned services
  extras     Install optional native and AUR packages (best effort)

Default operation: core
EOF
}

check_prerequisites() {
	local root_fs
	local root_options

	PLATFORM="$(detect_platform)"
	case "$PLATFORM" in
	arch | cachyos) ;;
	*) die "Supported Linux platforms are Arch Linux and CachyOS (detected: $PLATFORM)" ;;
	esac

	[[ $EUID -ne 0 ]] || die "Run as a regular user, not root."
	command -v pacman >/dev/null 2>&1 || die "pacman is required."
	[[ -f /etc/arch-release ]] || die "No /etc/arch-release found."

	if ! ping -c 1 -W 5 archlinux.org >/dev/null 2>&1; then
		die "No network connectivity to archlinux.org."
	fi
	if ! sudo -n true 2>/dev/null; then
		log_info "Sudo authentication required."
		sudo -v
	fi

	root_fs="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
	root_options="$(findmnt -n -o OPTIONS / 2>/dev/null || true)"
	[[ ",${root_options}," == *,rw,* ]] ||
		die "Root is not mounted read-write. Stop and investigate the filesystem before deploying."

	if [[ "$root_fs" == "btrfs" ]] && command -v btrfs >/dev/null 2>&1; then
		log_info "Checking persistent Btrfs device error counters..."
		if ! sudo btrfs device stats -c /; then
			die "Btrfs reports device errors. Run 'sudo just health' and investigate before deploying."
		fi
	fi

	local available_gb
	available_gb="$(df -BG / | awk 'NR == 2 { gsub(/G/, "", $4); print $4 }')"
	[[ "${available_gb:-0}" -ge 5 ]] ||
		die "At least 5 GB free is required; found ${available_gb:-unknown} GB."

	log_info "Platform: $PLATFORM"
	log_info "The base OS remains responsible for boot, GPU, the graphical profile, networking, audio, power management, and filesystem configuration."
}

upgrade_system() {
	[[ "$NO_UPGRADE" -eq 0 ]] || {
		log_info "Skipping system upgrade (--no-upgrade)."
		return 0
	}

	log_info "Performing one full system upgrade using existing distro repositories and mirrors..."
	# Do not use pacman's undocumented `--ask` bitmask here. In particular,
	# `--ask 4` inverts the answer to package-conflict removal and can silently
	# replace a distro-owned package. A conflict must stop the bootstrap so the
	# user can review it.
	sudo pacman -Syu --noconfirm
}

read_list() {
	local file="$1"
	local -n output="$2"
	output=()
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line//[[:space:]]/}" ]] && continue
		output+=("$line")
	done <"$file"
}

install_native_list() {
	local file="$1"
	local packages=()
	[[ -f "$file" ]] || die "Package list not found: $file"
	read_list "$file" packages
	[[ ${#packages[@]} -gt 0 ]] || return 0
	log_info "Installing ${#packages[@]} native packages from $(basename "$file")..."
	sudo pacman -S --needed --noconfirm "${packages[@]}"
}

install_yay() {
	command -v yay >/dev/null 2>&1 && return 0

	log_info "Installing yay for optional AUR packages..."
	sudo pacman -S --needed --noconfirm base-devel git
	local build_dir
	build_dir="$(mktemp -d)"
	if ! git clone https://aur.archlinux.org/yay.git "${build_dir}/yay"; then
		rm -rf "$build_dir"
		return 1
	fi
	if ! (
		cd "${build_dir}/yay"
		makepkg -si --noconfirm
	); then
		rm -rf "$build_dir"
		return 1
	fi
	rm -rf "$build_dir"
}

install_aur_list() {
	local file="$1"
	local packages=()
	[[ -f "$file" ]] || die "AUR package list not found: $file"
	read_list "$file" packages
	[[ ${#packages[@]} -gt 0 ]] || return 0
	install_yay
	log_info "Installing ${#packages[@]} optional AUR packages from $(basename "$file")..."
	yay -S --needed --noconfirm "${packages[@]}"
}

enable_services() {
	local services=()
	read_list "${SCRIPT_DIR}/services/core.txt" services
	local service
	for service in "${services[@]}"; do
		if systemctl is-enabled "$service" >/dev/null 2>&1; then
			log_info "Service already enabled: $service"
		else
			sudo systemctl enable "$service"
			log_info "Enabled service: $service"
		fi
	done
}

configure_keyd() {
	local source="${REPO_ROOT}/dots/keyd/default.conf"
	local target="/etc/keyd/default.conf"
	command -v keyd >/dev/null 2>&1 || return 0
	[[ -f "$source" ]] || die "keyd configuration not found: $source"

	if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
		log_info "keyd configuration is current."
		return 0
	fi

	sudo install -Dm644 "$source" "$target"
	if systemctl is-active keyd >/dev/null 2>&1; then
		sudo keyd reload
	fi
	log_info "Installed keyd configuration."
}

set_default_shell() {
	[[ "$SHELL" == */zsh ]] && return 0
	command -v zsh >/dev/null 2>&1 || return 0
	chsh -s "$(command -v zsh)"
	log_info "Default shell changed to zsh for the next login."
}

write_core_marker() {
	local state_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/archway"
	mkdir -p "$state_dir"
	cat >"${state_dir}/core.complete" <<EOF
ARCHWAY_CORE_VERSION="${SCRIPT_VERSION}"
ARCHWAY_PLATFORM="${PLATFORM}"
ARCHWAY_CORE_COMPLETED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ARCHWAY_REPO_ROOT="${REPO_ROOT}"
EOF
	log_info "Recorded core completion in ${state_dir}/core.complete"
}

install_core() {
	CURRENT_PHASE="installing core packages"
	install_native_list "${SCRIPT_DIR}/pkgs/core.txt"
	CURRENT_PHASE="enabling Archway-owned services"
	enable_services
	CURRENT_PHASE="configuring keyd"
	configure_keyd
	CURRENT_PHASE="setting the login shell"
	set_default_shell
	write_core_marker
}

install_extras() {
	local failed=()

	CURRENT_PHASE="installing optional native extras"
	install_native_list "${SCRIPT_DIR}/pkgs/extras.txt" || failed+=("native extras")

	CURRENT_PHASE="installing optional AUR extras"
	install_aur_list "${SCRIPT_DIR}/pkgs/extras.aur.txt" || failed+=("AUR extras")

	if [[ ${#failed[@]} -gt 0 ]]; then
		log_warn "Core remains usable. Optional components failed: ${failed[*]}"
		log_warn "Retry later with: just extras"
		return 1
	fi
}

main() {
	local operation="core"
	NO_UPGRADE=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
		core | extras) operation="$1" ;;
		--no-upgrade) NO_UPGRADE=1 ;;
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

	BOOTSTRAP_STARTED=1
	CURRENT_PHASE="preflight"
	check_prerequisites

	if [[ "$operation" == "core" ]]; then
		CURRENT_PHASE="system upgrade"
		upgrade_system
	fi

	case "$operation" in
	core) install_core ;;
	extras) install_extras ;;
	esac

	CURRENT_PHASE="complete"
}

main "$@"
