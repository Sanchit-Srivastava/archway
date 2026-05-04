#!/usr/bin/env bash
set -euo pipefail

# Remote bootstrap for archway - fetched via:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) [profile]
#
# The fast path is a single positional arg: minimal | safe | full
#   bash <(curl ...) safe         # T1+T2+T3 (KDE Plasma fallback, no AUR/DMS)
#   bash <(curl ...) full         # T1-T4 (full install with DMS)
#   bash <(curl ...)              # defaults to full
#
# This script clones the repo and hands off to install.sh.
# All interactive prompts happen in install.sh, not here.
#
# Options (consumed here, not passed to install.sh):
#   --repo <url>   Override clone URL (default: github.com/Sanchit-Srivastava/archway)
#   --dir <path>   Clone destination (default: ~/archway)
#   --ref <ref>    Git ref to check out (tag, branch, or sha; default: main HEAD)
#                  Use this for reproducible installs:
#                    bash <(curl ...) --ref v2026.05.03 safe
#
# All other flags pass through to install.sh.

SCRIPT_VERSION="2026-05-03-2"

REPO_URL="https://github.com/Sanchit-Srivastava/archway.git"
REPO_DIR="${HOME}/archway"
REPO_REF=""

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

# --- Parse arguments (pass-through to install.sh, except --repo/--dir/--ref) ---
# Bare positional `safe`/`minimal`/`full` is sugar for `--profile <x>`.

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
	--ref)
		REPO_REF="$2"
		shift 2
		;;
	minimal | safe | full)
		PASSTHROUGH_ARGS+=(--profile "$1")
		shift
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
	if [[ -n "$REPO_REF" ]]; then
		log_info "Fetching ref: $REPO_REF"
		git -C "$REPO_DIR" fetch --tags origin || log_warn "Fetch failed - continuing with existing checkout"
		git -C "$REPO_DIR" checkout --detach "$REPO_REF" ||
			die "Failed to check out ref: $REPO_REF"
	else
		log_info "Pulling latest changes..."
		git -C "$REPO_DIR" pull --ff-only || log_warn "Pull failed - continuing with existing checkout"
	fi
else
	if [[ -e "$REPO_DIR" ]]; then
		die "Path exists but is not a git repo: $REPO_DIR"
	fi
	log_info "Cloning archway into $REPO_DIR..."
	git clone "$REPO_URL" "$REPO_DIR"
	if [[ -n "$REPO_REF" ]]; then
		log_info "Checking out ref: $REPO_REF"
		git -C "$REPO_DIR" fetch --tags origin || true
		git -C "$REPO_DIR" checkout --detach "$REPO_REF" ||
			die "Failed to check out ref: $REPO_REF"
	fi
fi

# --- Hand off to install.sh ---
log_info "archway remote-install (v${SCRIPT_VERSION})"
log_info "Repo dir: $REPO_DIR | Ref: ${REPO_REF:-main HEAD} | Forwarded args: ${PASSTHROUGH_ARGS[*]:-<none>}"

# Ensure stdin is the terminal, not a pipe.
# This is the belt-and-suspenders fix: even if someone mistakenly runs
# `curl ... | bash` instead of `bash <(curl ...)`, interactive prompts
# will still work because we reconnect stdin to /dev/tty.
if [[ ! -t 0 ]]; then
	log_warn "stdin is not a terminal - redirecting from /dev/tty"
	exec </dev/tty
fi

if [[ ! -f "$REPO_DIR/install.sh" ]]; then
	die "install.sh not found at $REPO_DIR/install.sh - clone or checkout did not produce expected layout. Try: rm -rf $REPO_DIR && re-run."
fi

log_info "Handing off to install.sh..."
exec bash "$REPO_DIR/install.sh" "${PASSTHROUGH_ARGS[@]}"
