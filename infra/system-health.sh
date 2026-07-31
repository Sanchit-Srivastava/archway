#!/usr/bin/env bash
set -euo pipefail

# Read-only deployment preflight and diagnostic report.
# This script never repairs, remounts, scrubs, balances, or resets counters.

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

errors=0
warnings=0

pass() {
	log_info "$1"
}

warn() {
	warnings=$((warnings + 1))
	log_warn "$1"
}

fail() {
	errors=$((errors + 1))
	log_error "$1"
}

print_command() {
	local heading="$1"
	shift
	printf '\n%s\n' "$heading"
	if ! "$@"; then
		warn "Could not collect: $*"
	fi
}

check_root_mount() {
	local fs_type
	local options

	fs_type="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
	options="$(findmnt -n -o OPTIONS / 2>/dev/null || true)"
	if [[ -z "$fs_type" || -z "$options" ]]; then
		fail "Could not inspect the root mount."
		return
	fi

	printf 'Root filesystem: %s (%s)\n' "$fs_type" "$options"
	if [[ ",${options}," == *,rw,* ]]; then
		pass "Root is mounted read-write."
	else
		fail "Root is not mounted read-write. Do not deploy or run package operations."
	fi
}

check_space() {
	local available_kb
	local available_gb

	available_kb="$(df -Pk / | awk 'NR == 2 { print $4 }')"
	available_gb=$((available_kb / 1024 / 1024))
	if ((available_gb >= 10)); then
		pass "Root has at least 10 GiB available (${available_gb} GiB)."
	elif ((available_gb >= 5)); then
		warn "Root has only ${available_gb} GiB available; large upgrades and snapshots need headroom."
	else
		fail "Root has only ${available_gb} GiB available."
	fi
}

check_btrfs() {
	[[ "$(findmnt -n -o FSTYPE / 2>/dev/null || true)" == "btrfs" ]] || return 0

	if ! command -v btrfs >/dev/null 2>&1; then
		warn "Root is Btrfs but btrfs-progs is unavailable."
		return
	fi

	print_command "Btrfs allocation:" btrfs filesystem usage -T /
	print_command "Btrfs device error counters:" btrfs device stats /
	print_command "Btrfs scrub status:" btrfs scrub status /

	if [[ $EUID -eq 0 ]]; then
		if btrfs device stats -c / >/dev/null 2>&1; then
			pass "Btrfs device error counters are zero."
		else
			fail "Btrfs has non-zero device error counters. Investigate before deploying."
		fi
	else
		warn "Run 'sudo just health' to make Btrfs error counters affect the final status."
	fi
}

show_kernel_errors() {
	local pattern='BTRFS.*(error|critical|corrupt|readonly)|I/O error|nvme.*(reset|timeout|abort)|pcieport.*AER'
	printf '\nRelevant kernel messages from this boot:\n'
	if ! journalctl -k -b --no-pager 2>/dev/null |
		grep -Ei "$pattern" |
		tail -n 100; then
		printf '%s\n' "(none found, or the journal is not readable)"
	fi
}

main() {
	command -v findmnt >/dev/null 2>&1 || {
		log_error "findmnt is required."
		exit 1
	}

	check_root_mount
	check_space
	check_btrfs
	show_kernel_errors

	printf '\nHealth summary: %d error(s), %d warning(s)\n' "$errors" "$warnings"
	if ((errors > 0)); then
		log_error "Health checks failed. Do not deploy until the errors are understood."
		return 1
	fi
	pass "No blocking filesystem condition was detected."
}

main "$@"
