#!/usr/bin/env bash
set -euo pipefail

# Remote bootstrap for archway - fetched via:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh)
#
# This script clones the repo and hands off to install.sh.
# All interactive prompts happen in install.sh, not here.

SCRIPT_VERSION="2026-03-12-1"

REPO_URL="https://github.com/Sanchit-Srivastava/archway.git"
REPO_DIR="${HOME}/archway"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

die() {
	log_error "$1"
	exit 1
}

# --- Parse arguments (pass-through to install.sh, except --repo/--dir) ---

PASSTHROUGH_ARGS=()
while [[ $# -gt 0 ]]; do
	case "$1" in
	--repo)
		REPO_URL="$2"
		shift 2
		;;
	--dir)
		REPO_DIR="$2"
		shift 2
		;;
	*)
		PASSTHROUGH_ARGS+=("$1")
		shift
		;;
	esac
done

# --- Preflight ---

if [[ $EUID -eq 0 ]]; then
	die "Do not run as root. Run as your regular user."
fi

if ! command -v git >/dev/null 2>&1; then
	log_info "Installing git..."
	sudo pacman -S --needed --noconfirm git
fi

# --- Clone or update repo ---

if [[ -d "$REPO_DIR/.git" ]]; then
	log_info "Repo already exists at $REPO_DIR"
	log_info "Pulling latest changes..."
	git -C "$REPO_DIR" pull --ff-only || log_warn "Pull failed - continuing with existing checkout"
else
	if [[ -e "$REPO_DIR" ]]; then
		die "Path exists but is not a git repo: $REPO_DIR"
	fi
	log_info "Cloning archway into $REPO_DIR..."
	git clone "$REPO_URL" "$REPO_DIR"
fi

# --- Hand off to install.sh ---
log_info "archway remote-install (v${SCRIPT_VERSION})"

# Ensure stdin is the terminal, not a pipe.
# This is the belt-and-suspenders fix: even if someone mistakenly runs
# `curl ... | bash` instead of `bash <(curl ...)`, interactive prompts
# will still work because we reconnect stdin to /dev/tty.
if [[ ! -t 0 ]]; then
	log_warn "stdin is not a terminal - redirecting from /dev/tty"
	exec </dev/tty
fi

log_info "Handing off to install.sh..."
exec "$REPO_DIR/install.sh" "${PASSTHROUGH_ARGS[@]}"
