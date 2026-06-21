#!/usr/bin/env bash
set -euo pipefail

# Helper: output a list of packages suitable for archinstall's
# "Additional packages" step (or for a config file).
#
# This lets you pull packages from the archway tier lists *during*
# the archinstall phase itself (instead of post-install via bootstrap).
#
# Especially useful when using Ventoy and you have the repo on the
# USB data partition.
#
# Usage examples:
#   ./infra/list-additional-packages.sh
#   ./infra/list-additional-packages.sh --up-to 3
#   ./infra/list-additional-packages.sh --up-to 2 --no-tex
#   ./infra/list-additional-packages.sh --profile safe
#
# Output is one package per line (easy to paste or redirect).
#
# Notes:
#   - Only native (pacman) packages are listed. AUR packages must still
#     be installed later via bootstrap.
#   - TeX is excluded by default because it is huge. Add --with-tex if desired.
#   - Always adds a small set of essentials (curl, git, etc.) that are
#     useful in the live environment / early post-install.

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

UP_TO=4
INCLUDE_TEX=0
PROFILE=""

usage() {
	cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --up-to N          Include tiers 1..N (1=base, 2=shell, 3=desktop, 4=extras)
  --profile NAME     Shortcut: minimal (2), safe (3), full (4)
  --with-tex         Include the heavy LaTeX packages (default: exclude)
  --no-tex           Explicitly exclude LaTeX (default behavior)
  -h, --help         Show this help

The output is intended to be pasted into archinstall's additional packages
prompt, or fed into an archinstall config.json.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--up-to)
		UP_TO="$2"
		shift 2
		;;
	--profile)
		PROFILE="$2"
		shift 2
		;;
	--with-tex)
		INCLUDE_TEX=1
		shift
		;;
	--no-tex)
		INCLUDE_TEX=0
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		log_error "Unknown option: $1"
		usage
		exit 1
		;;
	esac
done

if [[ -n "$PROFILE" ]]; then
	case "$PROFILE" in
	minimal) UP_TO=2 ;;
	safe) UP_TO=3 ;;
	full) UP_TO=4 ;;
	*)
		log_error "Unknown profile: $PROFILE"
		exit 1
		;;
	esac
fi

# Map up-to to tier prefixes
TIERS=()
for ((i = 1; i <= UP_TO; i++)); do
	case "$i" in
	1) TIERS+=("10-base") ;;
	2) TIERS+=("20-shell") ;;
	3) TIERS+=("30-desktop") ;;
	4) TIERS+=("40-extras") ;;
	esac
done

PACKAGES=()

# Always suggest a few things that are handy very early (live ISO / first boot)
ESSENTIALS=(curl git)
for p in "${ESSENTIALS[@]}"; do
	PACKAGES+=("$p")
done

# Collect from tier files
for tier in "${TIERS[@]}"; do
	file="${SCRIPT_DIR}/pkgs/${tier}.txt"
	[[ -f "$file" ]] || continue

	while IFS= read -r line || [[ -n "$line" ]]; do
		# skip comments and blank
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// /}" ]] && continue

		# Skip TeX unless explicitly requested
		if [[ "$INCLUDE_TEX" -eq 0 ]]; then
			[[ "$line" =~ ^texlive- ]] && continue
			[[ "$line" == "biber" ]] && continue
			[[ "$line" == "python-pynvim" ]] && continue
		fi

		PACKAGES+=("$line")
	done <"$file"
done

# Include dedicated tex list when requested (even though it's not in the tier files)
if [[ "$INCLUDE_TEX" -eq 1 ]]; then
	tex_file="${SCRIPT_DIR}/pkgs/tex.txt"
	if [[ -f "$tex_file" ]]; then
		while IFS= read -r line || [[ -n "$line" ]]; do
			[[ "$line" =~ ^[[:space:]]*# ]] && continue
			[[ -z "${line// /}" ]] && continue
			PACKAGES+=("$line")
		done <"$tex_file"
	fi
fi

# Deduplicate while preserving order
seen=()
for pkg in "${PACKAGES[@]}"; do
	if [[ " ${seen[*]} " != *" $pkg "* ]]; then
		seen+=("$pkg")
	fi
done

# Print one per line (best for pasting into archinstall)
printf '%s\n' "${seen[@]}"
