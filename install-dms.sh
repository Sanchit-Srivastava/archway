#!/usr/bin/env bash
set -euo pipefail

# DankMaterialShell installer wrapper
# https://install.danklinux.com

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

main() {
    # Check not running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this script as root"
        log_error "Run as your regular user instead"
        exit 1
    fi

    # Check system baseline is installed (bootstrap provides D-Bus services DMS needs)
    local state_file
    state_file="${XDG_CONFIG_HOME:-${HOME}/.config}/archway/bootstrap.complete"
    if [[ ! -f "$state_file" ]]; then
        log_warn "Bootstrap completion marker not found"
        log_warn "Expected: $state_file"
        if [[ -t 0 ]]; then
            read -r -p "Continue anyway? [y/N] " response
        else
            response="n"
            log_warn "Non-interactive shell detected; defaulting to 'no'"
        fi
        if [[ ! "${response:-}" =~ ^[Yy]$ ]]; then
            log_error "System baseline not ready"
            log_error "Run ./infra/bootstrap.sh first"
            exit 1
        fi
    fi

    log_info "Installing DankMaterialShell..."
    log_info ""
    log_warn "This will install the DMS desktop shell and compositor (niri or Hyprland)"
    log_warn "Your existing compositor config may be modified"
    log_info ""
    
    if [[ -t 0 ]]; then
        read -r -p "Continue? [y/N] " response
    else
        response="n"
        log_warn "Non-interactive shell detected; defaulting to 'no'"
    fi
    if [[ ! "${response:-}" =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi

    # Run the DMS installer
    curl -fsSL https://install.danklinux.com | sh

    log_info ""
    log_info "DMS installation complete!"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Log out and back in (or reboot)"
    log_info "  2. Select your compositor session (niri or Hyprland) from SDDM"
    log_info "  3. DMS should start automatically"
    log_info ""
    log_info "To update DMS later: dms update"
}

main "$@"
