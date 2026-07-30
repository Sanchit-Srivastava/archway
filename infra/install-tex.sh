#!/usr/bin/env bash
set -euo pipefail

# Standalone installer for the LaTeX / TeX toolchain.
#
# This is deliberately separate from the normal install.
# TeX Live is large and time-consuming. During a desperate reinstall
# on limited bandwidth (phone hotspot, etc.) you probably want a working
# system first.
#
# Once you have a usable desktop, run this to get a full LaTeX setup
# (vimtex + SyncTeX via zathura + biber + comprehensive texlive).
#
# Usage:
#   ./infra/install-tex.sh
#   just tex                 # via Justfile
#
# Safe to re-run (uses --needed).

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

PKGS_FILE="${SCRIPT_DIR}/pkgs/tex.txt"

if [[ ! -f "$PKGS_FILE" ]]; then
	log_error "Package list not found: $PKGS_FILE"
	exit 1
fi

# Read packages (ignore comments and blank lines)
mapfile -t packages < <(grep -v '^[[:space:]]*#' "$PKGS_FILE" | grep -v '^[[:space:]]*$')

if [[ ${#packages[@]} -eq 0 ]]; then
	log_info "No packages listed in $PKGS_FILE"
	exit 0
fi

log_info "Installing LaTeX / TeX toolchain (${#packages[@]} packages)..."
log_info "This can take a long time on the first run."

sudo pacman -S --needed --noconfirm "${packages[@]}"

log_info "TeX installation complete."
log_info ""
log_info "Next steps (if not already done):"
log_info "  - Restart your editor (nvim) so vimtex picks up the new installation."
log_info "  - Open a .tex file and test forward/inverse search with zathura."
log_info "  - You may want to run: sudo mktexlsr   (rarely needed)"
