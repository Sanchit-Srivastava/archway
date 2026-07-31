#!/usr/bin/env bash
set -euo pipefail

# Pasteable first-stage launcher. It only clones/selects the repository and
# hands off to install.sh; all target-machine work lives in the checked-out
# version so it is reviewable and retryable.
#
# Options (consumed here, not passed to install.sh):
#   --repo <url>   Override clone URL (default: github.com/Sanchit-Srivastava/archway)
#   --dir <path>   Clone destination (default: ~/archway)
#   --ref <ref>    Git ref to check out (tag, branch, or sha; default: main HEAD)
#                  Use this for reproducible installs:
#                    bash <(curl ...) --ref v2026.05.03 safe
#
# A bare `safe` argument is accepted as shorthand for `--safe`.

SCRIPT_VERSION="2026-07-29-1"

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
# Bare `safe` is sugar for `--safe`.

PASSTHROUGH_ARGS=()
while [[ $# -gt 0 ]]; do
	case "$1" in
	--repo)
		[[ $# -ge 2 ]] || die "--repo requires a value"
		REPO_URL="$2"
		shift 2
		;;
	--dir)
		[[ $# -ge 2 ]] || die "--dir requires a value"
		REPO_DIR="$2"
		shift 2
		;;
	--ref)
		[[ $# -ge 2 ]] || die "--ref requires a value"
		REPO_REF="$2"
		shift 2
		;;
	safe)
		PASSTHROUGH_ARGS+=(--safe)
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

if command -v findmnt >/dev/null 2>&1; then
	ROOT_OPTIONS="$(findmnt -n -o OPTIONS / 2>/dev/null || true)"
	[[ ",${ROOT_OPTIONS}," == *,rw,* ]] ||
		die "Root is not mounted read-write. Stop and investigate the filesystem before deploying."
fi

if ! command -v git >/dev/null 2>&1; then
	log_info "Updating the system and installing git..."
	sudo pacman -Syu --needed --noconfirm git
fi

# --- Clone or update repo ---

if [[ -d "$REPO_DIR/.git" ]]; then
	log_info "Repo already exists at $REPO_DIR"
	if [[ -n "$REPO_REF" ]]; then
		log_info "Fetching ref: $REPO_REF"
		git -C "$REPO_DIR" fetch --tags origin ||
			die "Failed to fetch the requested ref."
		git -C "$REPO_DIR" checkout --detach "$REPO_REF" ||
			die "Failed to check out ref: $REPO_REF"
	else
		log_info "Pulling latest changes..."
		git -C "$REPO_DIR" pull --ff-only ||
			die "Failed to fast-forward the existing checkout. Resolve it before installing."
	fi
else
	if [[ -e "$REPO_DIR" ]]; then
		die "Path exists but is not a git repo: $REPO_DIR"
	fi
	log_info "Cloning archway into $REPO_DIR..."
	git clone "$REPO_URL" "$REPO_DIR"
	if [[ -n "$REPO_REF" ]]; then
		log_info "Checking out ref: $REPO_REF"
		git -C "$REPO_DIR" fetch --tags origin ||
			die "Failed to fetch the requested ref."
		git -C "$REPO_DIR" checkout --detach "$REPO_REF" ||
			die "Failed to check out ref: $REPO_REF"
	fi
fi

# --- Hand off to install.sh ---
log_info "Archway remote installer v${SCRIPT_VERSION}"
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
