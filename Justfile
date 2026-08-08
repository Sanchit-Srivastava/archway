# archway command surface

default:
    @just --list

# Complete first stage: core, dotfiles, secrets, and DMS.
install:
    ./install.sh install

# Panic/recovery mode: reliable core only; the base desktop remains available.
install-safe:
    ./install.sh install --safe

# Complete DMS preferences after logging into niri once.
finish:
    ./install.sh finish

# Reliable native package baseline.
core:
    ./infra/bootstrap.sh core

# Optional native and AUR applications. Failures do not invalidate core.
extras:
    ./infra/bootstrap.sh extras

# Install/retry DMS and generate its compositor defaults.
dms:
    ./install.sh dms

# Apply portable DMS preferences after its first launch.
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

# Heavy optional Zotero installation.
zotero:
    ./infra/bootstrap.sh zotero --no-upgrade

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
    shellcheck -x -P SCRIPTDIR infra/lib/*.sh infra/*.sh install.sh remote-install.sh install-dms.sh

# Read-only target-system filesystem and kernel-error report.
health:
    ./infra/system-health.sh

# Format shell files in place.
fmt:
    shfmt -w infra/lib/*.sh infra/*.sh install.sh remote-install.sh install-dms.sh

# Check formatting without modifying files.
check-fmt:
    shfmt -d infra/lib/*.sh infra/*.sh install.sh remote-install.sh install-dms.sh
