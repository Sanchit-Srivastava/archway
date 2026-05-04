# archway Justfile
# https://github.com/casey/just

# Default recipe - show help
default:
    @just --list

# =============================================================================
# INSTALLATION
# =============================================================================

# Run full bootstrap (packages, services, configuration)
bootstrap:
    ./infra/bootstrap.sh

# Install user dotfiles
dotfiles:
    ./infra/dotfiles.sh

# Full setup: bootstrap + dotfiles
setup: bootstrap dotfiles
    @echo "Setup complete! Run './infra/doctor.sh' to validate."

# =============================================================================
# VALIDATION
# =============================================================================

# Run all system checks
doctor:
    ./infra/doctor.sh

# Run specific check (e.g., just check pipewire)
check id:
    ./infra/doctor.sh --only {{id}}

# List available checks
checks:
    ./infra/doctor.sh --list

# Audit packages (detect drift)
audit:
    ./infra/doctor.sh --audit-packages

# =============================================================================
# MAINTENANCE
# =============================================================================

# Pull latest, run bootstrap, validate
sync:
    git pull
    ./infra/bootstrap.sh
    ./infra/dotfiles.sh
    ./infra/doctor.sh

# Pull live DMS/niri configs into repo (run after changing settings)
pull-dots:
    ./infra/pull-dots.sh

# Update system packages
update:
    sudo pacman -Syu
    yay -Syu

# Create pre-bootstrap snapshot (Btrfs only)
snapshot:
    sudo ./infra/pre-bootstrap.sh create

# =============================================================================
# HARDWARE / GAMING (CachyOS extras)
# =============================================================================

# Configure third-party repos (multilib, CachyOS, chaotic-aur). Idempotent.
# Bootstrap calls this automatically; run manually to refresh repo setup.
setup-repos:
    ./infra/setup-repos.sh

# Detect hardware and install matching driver profiles via chwd
# (e.g. NVIDIA dkms stack). Run once after first boot, then reboot.
hwdetect:
    sudo chwd -a

# Show available chwd profiles for detected hardware (no install)
hwdetect-list:
    sudo chwd -l

# =============================================================================
# SECRETS (SOPS + age)
# =============================================================================

# Edit an encrypted secrets file (decrypts → $EDITOR → re-encrypts)
secrets-edit file:
    sops secrets/{{file}}

# Encrypt all plaintext secrets files in-place (first-time setup)
secrets-encrypt:
    @for f in secrets/opencode.env secrets/research-tools.env secrets/vdirsyncer.env secrets/ssh_config.local; do \
        if grep -q 'sops_version=' "$f" 2>/dev/null || grep -q '"sops"' "$f" 2>/dev/null; then \
            echo "Already encrypted: $f"; \
        else \
            sops --encrypt --in-place "$f" && echo "Encrypted: $f"; \
        fi; \
    done

# Show decrypted secrets (stdout only — does not write files)
secrets-show file:
    sops --decrypt secrets/{{file}}

# =============================================================================
# DEVELOPMENT
# =============================================================================

# Lint shell scripts
lint:
    shellcheck infra/*.sh

# Format shell scripts
fmt:
    shfmt -w infra/*.sh

# =============================================================================
# macOS
# =============================================================================

# Run macOS bootstrap (Homebrew packages + shell config)
bootstrap-mac:
    ./infra/bootstrap-mac.sh

# Full macOS setup: bootstrap + dotfiles
setup-mac: bootstrap-mac dotfiles
    @echo "macOS setup complete!"
