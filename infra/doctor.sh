#!/usr/bin/env bash
set -euo pipefail

# Doctor script: runtime validation of laptop-critical functionality
# Outputs structured results for automated checking

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# Colors for human-readable output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Output format (human or tap)
FORMAT="${DOCTOR_FORMAT:-human}"

# Filter to run only specific checks (empty means all)
ONLY_CHECK=""

# Check ID mapping for --only filtering
declare -A CHECK_IDS=(
    [pipewire]="check_pipewire_running"
    [pipewire-pulse]="check_pipewire_pulse"
    [wireplumber]="check_wireplumber_running"
    [xdg-portal]="check_xdg_portal_running"
    [niri]="check_niri_installed"
    [portal-config]="check_portal_configuration"
    [wayland-tools]="check_essential_wayland_tools"
    [terminal]="check_terminal_installed"
    [file-manager]="check_file_manager_installed"
    [polkit-agent]="check_polkit_agent"
    [secret-service]="check_secret_service"
    [pam-keyring]="check_pam_keyring"
    [user-services]="check_user_services_enabled"
    [networkmanager]="check_network_manager"
    [bluetooth]="check_bluetooth"
    [udisks2]="check_udisks2"
    [polkit]="check_polkit"
    [accounts-daemon]="check_accounts_daemon"
    [yay]="check_yay_installed"
    [zsh]="check_zsh_installed"
    [dotfiles]="check_dotfiles_linked"
    [starship]="check_starship"
    [starship-config]="check_starship_config"
    [zoxide]="check_zoxide"
    [eza]="check_eza"
    [bat]="check_bat"
    [fzf]="check_fzf"
    [fd]="check_fd"
    [ripgrep]="check_ripgrep"
    [lazygit]="check_lazygit"
    [environment-d]="check_environment_d"
    [btrfs]="check_btrfs_root"
    [snapper]="check_snapper_configured"
    [snapper-timers]="check_snapper_timers"
    [grub-btrfs]="check_grub_btrfs"
    [plasma]="check_plasma_fallback"
    [dms]="check_dms_installed"
)

# Print TAP header
tap_plan() {
    if [[ "$FORMAT" == "tap" ]]; then
        echo "1..$1"
    fi
}

# Print TAP result
tap_result() {
    local status="$1"
    local num="$2"
    local name="$3"
    local message="${4:-}"

    if [[ "$FORMAT" == "tap" ]]; then
        if [[ "$status" == "ok" ]]; then
            echo "ok $num - $name"
        else
            echo "not ok $num - $name"
            if [[ -n "$message" ]]; then
                echo "  ---"
                echo "  message: $message"
                echo "  ..."
            fi
        fi
    fi
}

# Log helpers for human format
log_info() { [[ "$FORMAT" == "human" ]] && printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_pass() { [[ "$FORMAT" == "human" ]] && printf "${GREEN}[PASS]${NC} %s\n" "$1"; }
log_fail() { [[ "$FORMAT" == "human" ]] && printf "${RED}[FAIL]${NC} %s\n" "$1" >&2; }
log_warn() { [[ "$FORMAT" == "human" ]] && printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }

# Run a single check
run_check() {
    local name="$1"
    local command="$2"
    local fix_message="${3:-See docs/ARCHITECTURE.md for fixes}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local num=$TOTAL_TESTS

    if eval "$command" >/dev/null 2>&1; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        tap_result "ok" "$num" "$name"
        log_pass "$name"
        return 0
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        tap_result "not ok" "$num" "$name" "$fix_message"
        log_fail "$name"
        [[ "$FORMAT" == "human" ]] && log_warn "Fix: $fix_message"
        return 1
    fi
}

# =============================================================================
# INDIVIDUAL CHECKS
# =============================================================================

check_pipewire_running() {
    run_check \
        "PipeWire service active" \
        "systemctl --user is-active pipewire" \
        "Enable PipeWire: systemctl --user enable --now pipewire"
}

check_wireplumber_running() {
    run_check \
        "WirePlumber session manager active" \
        "systemctl --user is-active wireplumber" \
        "Enable WirePlumber: systemctl --user enable --now wireplumber"
}

check_pipewire_pulse() {
    run_check \
        "PipeWire PulseAudio compatibility" \
        "systemctl --user is-active pipewire-pulse" \
        "Enable: systemctl --user enable --now pipewire-pulse"
}

check_xdg_portal_running() {
    run_check \
        "xdg-desktop-portal service active" \
        "systemctl --user is-active xdg-desktop-portal" \
        "Enable portal: systemctl --user enable --now xdg-desktop-portal"
}

check_niri_installed() {
    run_check \
        "niri compositor installed" \
        "command -v niri" \
        "Install niri: sudo pacman -S niri (or DMS installer will install it)"
}

check_portal_configuration() {
    run_check \
        "Portal backend configured for niri" \
        "test -f /etc/xdg/xdg-desktop-portal/portals.conf && grep -q 'gnome' /etc/xdg/xdg-desktop-portal/portals.conf" \
        "Run bootstrap.sh to configure portal backend"
}

check_essential_wayland_tools() {
    run_check \
        "Essential Wayland tools installed" \
        "command -v grim && command -v slurp && command -v wl-copy" \
        "Install tools: sudo pacman -S grim slurp wl-clipboard"
}

check_terminal_installed() {
    run_check \
        "Terminal emulator installed" \
        "command -v foot || command -v alacritty || command -v kitty || command -v ghostty" \
        "Install a terminal: sudo pacman -S foot"
}

check_file_manager_installed() {
    run_check \
        "File manager installed" \
        "command -v nautilus || command -v dolphin || command -v thunar" \
        "Install file manager: sudo pacman -S nautilus"
}

check_polkit_agent() {
    run_check \
        "Polkit agent running" \
        "pgrep -f 'polkit-agent|polkit-kde|polkit-gnome|lxqt-policykit|dms'" \
        "DMS provides polkit agent, or start polkit-gnome manually"
}

check_secret_service() {
    run_check \
        "Secret service responding" \
        "busctl --user list | grep -q 'org.freedesktop.secrets'" \
        "Install and enable gnome-keyring: pacman -S gnome-keyring"
}

check_pam_keyring() {
    run_check \
        "PAM configured for gnome-keyring" \
        "grep -q 'pam_gnome_keyring.so' /etc/pam.d/login" \
        "Run bootstrap.sh to configure PAM for gnome-keyring"
}

check_user_services_enabled() {
    local all_enabled=true
    local services=("pipewire" "pipewire-pulse" "wireplumber" "xdg-desktop-portal")
    
    for svc in "${services[@]}"; do
        if ! systemctl --user is-enabled "$svc" >/dev/null 2>&1; then
            all_enabled=false
            break
        fi
    done
    
    run_check \
        "User services enabled" \
        "$all_enabled" \
        "Enable: systemctl --user enable pipewire pipewire-pulse wireplumber xdg-desktop-portal"
}

check_network_manager() {
    run_check \
        "NetworkManager service enabled" \
        "systemctl is-enabled NetworkManager" \
        "Enable: sudo systemctl enable --now NetworkManager"
}

check_bluetooth() {
    run_check \
        "Bluetooth service enabled" \
        "systemctl is-enabled bluetooth" \
        "Enable: sudo systemctl enable --now bluetooth"
}

check_udisks2() {
    run_check \
        "udisks2 service enabled (removable media)" \
        "systemctl is-enabled udisks2" \
        "Enable: sudo systemctl enable --now udisks2"
}

check_polkit() {
    run_check \
        "polkit service enabled" \
        "systemctl is-enabled polkit" \
        "Enable: sudo systemctl enable --now polkit"
}

check_accounts_daemon() {
    run_check \
        "accounts-daemon service enabled (DMS user info)" \
        "systemctl is-enabled accounts-daemon" \
        "Enable: sudo systemctl enable --now accounts-daemon"
}

check_dms_installed() {
    run_check \
        "DMS shell installed (quickshell/qs)" \
        "command -v qs" \
        "Install DMS: curl -fsSL https://dms.avenge.cloud | bash"
}

check_yay_installed() {
    run_check \
        "yay AUR helper installed" \
        "command -v yay" \
        "Install yay: see bootstrap.sh"
}

check_zsh_installed() {
    run_check \
        "Zsh shell installed" \
        "command -v zsh" \
        "Install zsh: sudo pacman -S zsh"
}

check_dotfiles_linked() {
    run_check \
        "Dotfiles linked (~/.zshrc)" \
        "test -L ${HOME}/.zshrc" \
        "Run: ./infra/dotfiles.sh"
}

# Shell tool checks
check_starship() {
    run_check \
        "Starship prompt installed" \
        "command -v starship" \
        "Install: sudo pacman -S starship"
}

check_zoxide() {
    run_check \
        "Zoxide (smart cd) installed" \
        "command -v zoxide" \
        "Install: sudo pacman -S zoxide"
}

check_eza() {
    run_check \
        "Eza (modern ls) installed" \
        "command -v eza" \
        "Install: sudo pacman -S eza"
}

check_bat() {
    run_check \
        "Bat (modern cat) installed" \
        "command -v bat" \
        "Install: sudo pacman -S bat"
}

check_fzf() {
    run_check \
        "Fzf (fuzzy finder) installed" \
        "command -v fzf" \
        "Install: sudo pacman -S fzf"
}

check_fd() {
    run_check \
        "Fd (modern find) installed" \
        "command -v fd" \
        "Install: sudo pacman -S fd"
}

check_ripgrep() {
    run_check \
        "Ripgrep (modern grep) installed" \
        "command -v rg" \
        "Install: sudo pacman -S ripgrep"
}

check_lazygit() {
    run_check \
        "Lazygit (git TUI) installed" \
        "command -v lazygit" \
        "Install: sudo pacman -S lazygit"
}

check_starship_config() {
    run_check \
        "Starship config linked" \
        "test -L ${HOME}/.config/starship.toml" \
        "Run: ./infra/dotfiles.sh"
}

check_environment_d() {
    run_check \
        "Environment.d config linked" \
        "test -L ${HOME}/.config/environment.d/50-archway.conf" \
        "Run: ./infra/dotfiles.sh"
}

# Btrfs checks
check_btrfs_root() {
    local fstype
    fstype=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "unknown")

    if [[ "$fstype" != "btrfs" ]]; then
        run_check \
            "Root filesystem is Btrfs (skipped - not Btrfs)" \
            "true" \
            ""
        return 0
    fi

    run_check \
        "Root filesystem is Btrfs" \
        "true" \
        ""
}

check_snapper_configured() {
    local fstype
    fstype=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "unknown")
    
    if [[ "$fstype" != "btrfs" ]]; then
        run_check \
            "Snapper configured (skipped - not Btrfs)" \
            "true" \
            ""
        return 0
    fi
    
    run_check \
        "Snapper 'root' config exists" \
        "snapper -c root list >/dev/null 2>&1" \
        "Run bootstrap.sh to configure snapper"
}

check_snapper_timers() {
    local fstype
    fstype=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "unknown")
    
    if [[ "$fstype" != "btrfs" ]]; then
        run_check \
            "Snapper timers enabled (skipped - not Btrfs)" \
            "true" \
            ""
        return 0
    fi
    
    run_check \
        "Snapper timeline timer enabled" \
        "systemctl is-enabled snapper-timeline.timer >/dev/null 2>&1" \
        "Enable: sudo systemctl enable --now snapper-timeline.timer"
}

check_grub_btrfs() {
    local fstype
    fstype=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "unknown")
    
    if [[ "$fstype" != "btrfs" ]]; then
        run_check \
            "grub-btrfs enabled (skipped - not Btrfs)" \
            "true" \
            ""
        return 0
    fi
    
    run_check \
        "grub-btrfs daemon enabled" \
        "systemctl is-enabled grub-btrfsd >/dev/null 2>&1" \
        "Enable: sudo systemctl enable --now grub-btrfsd"
}

check_plasma_fallback() {
    run_check \
        "KDE Plasma fallback installed" \
        "command -v startplasma-wayland" \
        "Install: sudo pacman -S plasma-desktop plasma-nm plasma-pa kscreen bluedevil"
}

# =============================================================================
# PACKAGE AUDIT
# =============================================================================

audit_packages() {
    local pkg_pacman="${SCRIPT_DIR}/pkgs.pacman.txt"
    local pkg_aur="${SCRIPT_DIR}/pkgs.aur.txt"
    local tmpdir
    tmpdir=$(mktemp -d)
    
    log_info "Auditing packages: comparing system state to repo lists..."
    echo ""
    
    # Get explicitly installed packages
    pacman -Qqen | sort > "${tmpdir}/explicit-native.txt"
    pacman -Qqem | sort > "${tmpdir}/explicit-foreign.txt"
    
    # Get repo lists
    if [[ -f "$pkg_pacman" ]]; then
        grep -v '^[[:space:]]*#' "$pkg_pacman" | grep -v '^[[:space:]]*$' | sort > "${tmpdir}/repo-native.txt"
    else
        touch "${tmpdir}/repo-native.txt"
    fi
    
    if [[ -f "$pkg_aur" ]]; then
        grep -v '^[[:space:]]*#' "$pkg_aur" | grep -v '^[[:space:]]*$' | sort > "${tmpdir}/repo-foreign.txt"
    else
        touch "${tmpdir}/repo-foreign.txt"
    fi
    
    # Compare
    comm -23 "${tmpdir}/explicit-native.txt" "${tmpdir}/repo-native.txt" > "${tmpdir}/untracked-native.txt"
    comm -23 "${tmpdir}/explicit-foreign.txt" "${tmpdir}/repo-foreign.txt" > "${tmpdir}/untracked-foreign.txt"
    comm -13 "${tmpdir}/explicit-native.txt" "${tmpdir}/repo-native.txt" > "${tmpdir}/missing-native.txt"
    comm -13 "${tmpdir}/explicit-foreign.txt" "${tmpdir}/repo-foreign.txt" > "${tmpdir}/missing-foreign.txt"
    
    # Count
    local untracked_native_count untracked_foreign_count missing_native_count missing_foreign_count
    untracked_native_count=$(wc -l < "${tmpdir}/untracked-native.txt" | tr -d ' ')
    untracked_foreign_count=$(wc -l < "${tmpdir}/untracked-foreign.txt" | tr -d ' ')
    missing_native_count=$(wc -l < "${tmpdir}/missing-native.txt" | tr -d ' ')
    missing_foreign_count=$(wc -l < "${tmpdir}/missing-foreign.txt" | tr -d ' ')
    
    # Display
    echo "========================================"
    echo "         PACKAGE AUDIT REPORT"
    echo "========================================"
    echo ""
    
    if [[ "$untracked_native_count" -gt 0 ]]; then
        printf "${YELLOW}Untracked native packages (%s):${NC}\n" "$untracked_native_count"
        sed 's/^/  - /' "${tmpdir}/untracked-native.txt"
        echo ""
        echo "  Action: Add to infra/pkgs.pacman.txt or remove"
        echo ""
    else
        printf "${GREEN}No untracked native packages${NC}\n"
    fi
    
    if [[ "$untracked_foreign_count" -gt 0 ]]; then
        printf "${YELLOW}Untracked AUR packages (%s):${NC}\n" "$untracked_foreign_count"
        sed 's/^/  - /' "${tmpdir}/untracked-foreign.txt"
        echo ""
        echo "  Action: Add to infra/pkgs.aur.txt or remove"
        echo ""
    else
        printf "${GREEN}No untracked AUR packages${NC}\n"
    fi
    
    if [[ "$missing_native_count" -gt 0 ]]; then
        printf "${YELLOW}Missing native packages (%s):${NC}\n" "$missing_native_count"
        sed 's/^/  - /' "${tmpdir}/missing-native.txt"
        echo ""
        echo "  Action: Run ./infra/bootstrap.sh to install"
        echo ""
    fi
    
    if [[ "$missing_foreign_count" -gt 0 ]]; then
        printf "${YELLOW}Missing AUR packages (%s):${NC}\n" "$missing_foreign_count"
        sed 's/^/  - /' "${tmpdir}/missing-foreign.txt"
        echo ""
        echo "  Action: Run ./infra/bootstrap.sh to install"
        echo ""
    fi
    
    # Summary
    local total_untracked=$((untracked_native_count + untracked_foreign_count))
    local total_missing=$((missing_native_count + missing_foreign_count))
    
    echo "========================================"
    if [[ "$total_untracked" -eq 0 && "$total_missing" -eq 0 ]]; then
        printf "${GREEN}System is in sync with repository${NC}\n"
        rm -rf "$tmpdir"
        return 0
    else
        printf "${YELLOW}Found %s untracked and %s missing packages${NC}\n" "$total_untracked" "$total_missing"
        rm -rf "$tmpdir"
        return 1
    fi
}

# =============================================================================
# SUMMARY
# =============================================================================

print_summary() {
    if [[ "$FORMAT" == "human" ]]; then
        echo ""
        echo "========================================"
        echo "           DOCTOR SUMMARY"
        echo "========================================"
        printf "Total checks:  %d\n" "$TOTAL_TESTS"
        printf "${GREEN}Passed:${NC}        %d\n" "$PASSED_TESTS"
        printf "${RED}Failed:${NC}        %d\n" "$FAILED_TESTS"
        echo "========================================"

        if [[ $FAILED_TESTS -eq 0 ]]; then
            echo "All checks passed! System is healthy."
            return 0
        else
            echo "Some checks failed. See messages above for fixes."
            return 1
        fi
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --format)
                FORMAT="$2"
                shift 2
                ;;
            --format=*)
                FORMAT="${1#*=}"
                shift
                ;;
            --list)
                echo "Available checks (use --only <id> to run a single check):"
                echo ""
                echo "  ID               Description"
                echo "  ---------------  ------------------------------------------"
                echo "  pipewire         PipeWire service active"
                echo "  pipewire-pulse   PipeWire PulseAudio compatibility"
                echo "  wireplumber      WirePlumber session manager active"
                echo "  xdg-portal       xdg-desktop-portal service active"
                echo "  portal-config    Portal backend configured for niri"
                echo "  niri             niri compositor installed"
                echo "  wayland-tools    Essential Wayland tools installed"
                echo "  terminal         Terminal emulator installed"
                echo "  file-manager     File manager installed"
                echo "  polkit-agent     Polkit agent running"
                echo "  secret-service   Secret service responding"
                echo "  pam-keyring      PAM configured for gnome-keyring"
                echo "  user-services    User services enabled"
                echo "  networkmanager   NetworkManager service enabled"
                echo "  bluetooth        Bluetooth service enabled"
                echo "  udisks2          udisks2 service enabled"
                echo "  polkit           polkit service enabled"
                echo "  accounts-daemon  accounts-daemon service enabled (DMS)"
                echo "  yay              yay AUR helper installed"
                echo "  zsh              Zsh shell installed"
                echo "  dotfiles         Dotfiles linked"
                echo ""
                echo "  # Shell Tools"
                echo "  starship         Starship prompt installed"
                echo "  starship-config  Starship config linked"
                echo "  zoxide           Zoxide (smart cd) installed"
                echo "  eza              Eza (modern ls) installed"
                echo "  bat              Bat (modern cat) installed"
                echo "  fzf              Fzf (fuzzy finder) installed"
                echo "  fd               Fd (modern find) installed"
                echo "  ripgrep          Ripgrep (modern grep) installed"
                echo "  lazygit          Lazygit (git TUI) installed"
                echo "  environment-d    Environment.d config linked"
                echo ""
                echo "  # Btrfs & Snapshots (conditional)"
                echo "  btrfs            Root filesystem is Btrfs"
                echo "  snapper          Snapper config exists"
                echo "  snapper-timers   Snapper timeline timer enabled"
                echo "  grub-btrfs       grub-btrfs daemon enabled"
                echo ""
                echo "  # Fallback Session"
                echo "  plasma           KDE Plasma fallback installed"
                echo ""
                echo "  # DMS (DankMaterialShell)"
                echo "  dms              DMS shell installed (quickshell/qs)"
                echo ""
                echo "Other modes:"
                echo "  --audit-packages   Compare installed packages to repo lists"
                exit 0
                ;;
            --only)
                ONLY_CHECK="$2"
                if [[ -z "${CHECK_IDS[$ONLY_CHECK]:-}" ]]; then
                    echo "error: unknown check id '$ONLY_CHECK'" >&2
                    echo "Run --list to see available check IDs" >&2
                    exit 1
                fi
                shift 2
                ;;
            --only=*)
                ONLY_CHECK="${1#*=}"
                if [[ -z "${CHECK_IDS[$ONLY_CHECK]:-}" ]]; then
                    echo "error: unknown check id '$ONLY_CHECK'" >&2
                    exit 1
                fi
                shift
                ;;
            --audit-packages)
                audit_packages
                exit $?
                ;;
            --help|-h)
                echo "Usage: doctor.sh [OPTIONS]"
                echo ""
                echo "Validate laptop-critical functionality"
                echo ""
                echo "Options:"
                echo "  --format FORMAT    Output format: human (default) or tap"
                echo "  --list             List available checks"
                echo "  --only ID          Run only the specified check"
                echo "  --audit-packages   Compare installed packages to repo lists"
                echo "  --help, -h         Show this help"
                exit 0
                ;;
            *)
                log_warn "Unknown option: $1"
                shift
                ;;
        esac
    done

    # Warn if no graphical session
    if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
        if [[ "$FORMAT" == "human" ]]; then
            log_warn "No graphical session detected. Some checks may fail."
        fi
    fi

    # Run checks
    if [[ -z "$ONLY_CHECK" ]]; then
        tap_plan 37
        
        check_pipewire_running
        check_pipewire_pulse
        check_wireplumber_running
        check_xdg_portal_running
        check_portal_configuration
        check_niri_installed
        check_essential_wayland_tools
        check_terminal_installed
        check_file_manager_installed
        check_polkit_agent
        check_secret_service
        check_pam_keyring
        check_user_services_enabled
        check_network_manager
        check_bluetooth
        check_udisks2
        check_polkit
        check_accounts_daemon
        check_yay_installed
        check_zsh_installed
        check_dotfiles_linked
        
        # Shell tools
        check_starship
        check_starship_config
        check_zoxide
        check_eza
        check_bat
        check_fzf
        check_fd
        check_ripgrep
        check_lazygit
        check_environment_d
        
        # Btrfs checks
        check_btrfs_root
        check_snapper_configured
        check_snapper_timers
        check_grub_btrfs
        
        # Fallback
        check_plasma_fallback
        
        # DMS (optional - may not be installed yet)
        check_dms_installed
    else
        tap_plan 1
        ${CHECK_IDS[$ONLY_CHECK]}
    fi

    print_summary
}

main "$@"
