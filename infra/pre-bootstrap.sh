#!/usr/bin/env bash
set -euo pipefail

# Pre-bootstrap snapshot creator for Btrfs systems
# Creates a snapshot before running bootstrap.sh for easy rollback

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

main() {
    local action="${1:-}"

    if [[ "$action" != "create" ]]; then
        echo "Usage: $0 create"
        echo ""
        echo "Creates a Btrfs snapshot named 'pre-bootstrap' before running bootstrap.sh"
        echo "This allows easy rollback if something goes wrong."
        echo ""
        echo "Requirements:"
        echo "  - Root filesystem must be Btrfs"
        echo "  - snapper must be installed and configured"
        echo "  - Must run as root (sudo)"
        exit 1
    fi

    # Check root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must run as root (use sudo)"
        exit 1
    fi

    # Check Btrfs
    local fstype
    fstype=$(findmnt -n -o FSTYPE /)
    if [[ "$fstype" != "btrfs" ]]; then
        log_error "Root filesystem is $fstype (not Btrfs)"
        log_error "Pre-bootstrap snapshots only work on Btrfs"
        exit 1
    fi

    # Check snapper
    if ! command -v snapper >/dev/null 2>&1; then
        log_error "snapper not installed"
        log_error "Install with: sudo pacman -S snapper"
        exit 1
    fi

    # Check snapper config exists
    if ! snapper -c root list >/dev/null 2>&1; then
        log_warn "Snapper 'root' config not found"
        log_warn "Run bootstrap.sh first to configure snapper, or create manually:"
        log_warn "  sudo snapper -c root create-config /"
        exit 1
    fi

    # Create snapshot
    log_info "Creating pre-bootstrap snapshot..."
    snapper -c root create --description "pre-bootstrap" --cleanup-algorithm "" --print-number

    log_info "Snapshot created successfully"
    log_info ""
    log_info "To rollback if something goes wrong:"
    log_info "  1. Reboot and select the snapshot from GRUB menu"
    log_info "  2. Or use: sudo snapper -c root rollback <number>"
    log_info ""
    log_info "To list snapshots: snapper list"
}

main "$@"
