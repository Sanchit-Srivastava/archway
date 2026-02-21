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

# Update system packages
update:
    sudo pacman -Syu
    yay -Syu

# Create pre-bootstrap snapshot (Btrfs only)
snapshot:
    sudo ./infra/pre-bootstrap.sh create

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
