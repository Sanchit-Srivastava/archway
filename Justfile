# archway command surface

default:
    @just --list

# Configure an existing Niri+DMS base; keep its chosen display manager.
install:
    ./install.sh install

# Core, dotfiles, and secrets only; leave the base desktop untouched.
install-minimal:
    ./install.sh minimal

# Reliable native package baseline.
core:
    ./infra/bootstrap.sh core

# Optional native and AUR applications. Failures do not invalidate core.
extras:
    ./infra/bootstrap.sh extras

# Reapply portable preferences from an active Niri+DMS session.
dms-config:
    ./install.sh dms-config

# Onboard/validate the age key and decrypt secret targets.
secrets:
    ./install.sh secrets

# Reapply ordinary dotfiles.
dotfiles:
    ./infra/dotfiles.sh

# Heavy optional LaTeX toolchain.
tex:
    ./infra/install-tex.sh

# Pull live niri files into the repo (DMS runtime JSON stays DMS-owned).
pull-dots:
    ./infra/pull-dots.sh

# Update packages using the distro's existing repositories.
update:
    sudo pacman -Syu
    @if command -v yay >/dev/null 2>&1; then yay -Sua; fi

# Pull Archway, reapply core and dotfiles. Optional components are not forced.
sync:
    git pull --ff-only
    ./infra/bootstrap.sh core --no-upgrade
    ./infra/dotfiles.sh

# Arch/systemd-boot-specific recovery tool. Never part of installation.
fix-boot:
    ./infra/fix-boot.sh

# Edit an encrypted secret.
secrets-edit file:
    sops secrets/{{file}}

# Show a decrypted secret on stdout.
secrets-show file:
    sops --decrypt secrets/{{file}}

# macOS user-environment installation.
bootstrap-mac:
    ./infra/bootstrap-mac.sh

# macOS packages plus shared dotfiles.
setup-mac: bootstrap-mac dotfiles

# Static shell analysis; never executes target-machine infrastructure.
lint:
    shellcheck -x -P SCRIPTDIR infra/lib/*.sh infra/*.sh install.sh remote-install.sh

# Isolated read-only helper tests; never invokes target installers.
test:
    python3 -B -m unittest discover -s tests -v

# Requires niri 26.04+; parse configs only, never starts a compositor.
check-niri:
    python3 -B tests/validate_niri.py -v

# Neovim theme discovery with stubbed DMS/plugin calls and temporary fixtures.
check-nvim:
    nvim --headless -u NONE -i NONE -n -l tests/validate_dms_theme.lua

# Read-only target-system filesystem and kernel-error report.
health:
    ./infra/system-health.sh

# Format shell files in place.
fmt:
    shfmt -w infra/lib/*.sh infra/*.sh install.sh remote-install.sh

# Check formatting without modifying files.
check-fmt:
    shfmt -d infra/lib/*.sh infra/*.sh install.sh remote-install.sh
