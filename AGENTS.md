# AGENTS.md - AI Coding Agent Instructions

This document provides instructions for AI coding agents working in the archway repository.

## Development vs Deployment

**CRITICAL**: This repo is developed on dev machines but deployed on target Arch Linux laptops.

- **DO NOT run bootstrap.sh, dotfiles.sh, doctor.sh, or any infra scripts** on the dev machine
- **DO NOT run `just bootstrap`, `just setup`, `just doctor`** - these are for the target laptop
- **Safe to run on dev machine**: `just lint`, `just fmt`, `shellcheck`, `shfmt`
- Scripts require Arch Linux, pacman, systemd, etc. - they will fail on non-Arch systems

When asked to verify changes, use static analysis (shellcheck, shfmt) rather than execution.

### Deployment order (target laptop, post-archinstall)

The scripts must run in this order on a fresh archinstall (ext4 + LUKS +
systemd-boot is the supported layout):

1. `just bootstrap` — installs packages, fixes systemd-boot/UKI layout,
   writes loader.conf, enables services. **Must run first.**
2. `just dotfiles` — symlinks configs, installs oh-my-zsh + plugins
   synchronously (NOT lazily from `.zshrc`).
3. `just doctor` — validates. Failures here on a fresh system usually mean
   step 1 was skipped.

Per-machine, opt-in (NOT part of the above sequence):

- **NVIDIA:** select the `nvidia-open` driver in archinstall (Turing+). archway
  does NOT script GPU driver setup — current drivers self-configure (nouveau
  blacklist, default modeset, dkms initramfs hook). The KWin-on-Wayland crash is
  a separate driver/compositor bug fixed by the Plasma X11 session, not config.
  See `docs/STABILITY.md` §2 and §4.
- `just fix-boot` — recover a vanished UEFI boot entry (`bootctl install` +
  fallback). Works from the running system or the Arch ISO via `arch-chroot`.
  Never reinstall the OS just to restore a boot entry.


## Project Overview

**archway** is a configuration-as-code repository for a reproducible Arch Linux laptop setup.
This is NOT a traditional software project - it contains shell scripts, dotfiles, and package
lists rather than application code.

| Component         | Technology                           |
| ----------------- | ------------------------------------ |
| Primary Language  | Bash shell scripts                   |
| Target OS         | Arch Linux                           |
| Secrets           | SOPS + age encryption                |
| Window Manager    | Hyprland (Wayland compositor)        |
| Task Runner       | [just](https://github.com/casey/just)|
| Shell             | Zsh with oh-my-zsh                   |
| Editor            | Neovim with LazyVim                  |
| Package Managers  | pacman (official), yay (AUR), Homebrew (macOS) |

## Build/Lint/Test Commands

### Task Runner (Justfile)

```bash
just                    # Show all available commands

# Installation
just bootstrap          # Run full system bootstrap (packages, services, config)
just dotfiles           # Install user dotfiles
just setup              # Full setup: bootstrap + dotfiles

# macOS Installation
just bootstrap-mac      # Run macOS bootstrap (Homebrew packages + shell)
just setup-mac          # Full macOS setup: bootstrap-mac + dotfiles

# Validation (this is "testing" for this repo)
just doctor             # Run ALL system checks
just check <id>         # Run a SINGLE check (e.g., just check pipewire)
just checks             # List available check IDs
just audit              # Audit packages (detect drift from repo lists)

# Maintenance
just sync               # Pull repo, run bootstrap, validate
just update             # Update system packages (pacman + AUR)

# Secrets
just secrets-edit <f>   # Decrypt-edit-reencrypt a secrets file (e.g., just secrets-edit opencode.env)
just secrets-encrypt    # Encrypt all plaintext secrets files in secrets/
just secrets-show <f>   # Print decrypted contents of a secrets file

# Development
just lint               # Lint shell scripts with shellcheck
just fmt                # Format shell scripts with shfmt
```

### Running Individual Checks

To run a single validation check:
```bash
./infra/doctor.sh --only <check-id>
# or
just check <check-id>
```

Available check IDs: `pipewire`, `wireplumber`, `xdg-portal`, `hyprland`, `bluetooth`,
`networkmanager`, `dotfiles`, etc. Run `just checks` for full list.

### Linting and Formatting

```bash
shellcheck infra/lib/*.sh infra/*.sh install.sh   # Static analysis (includes shared helpers)
shfmt -w infra/lib/*.sh infra/*.sh install.sh          # Format shell scripts (writes in place)
shfmt -d infra/*.sh     # Show diff without writing (for CI)
```

## Directory Structure

```
archway/
├── infra/                    # System baseline scripts
│   ├── bootstrap.sh          # Tiered system installer (Arch Linux)
│   ├── bootstrap-mac.sh      # macOS bootstrap (Homebrew + shell)
│   ├── dotfiles.sh           # User dotfile symlinker (cross-platform)
│   ├── doctor.sh             # System validation/health checks
│   ├── pkgs/                 # Per-tier package lists (Arch)
│   │   ├── 10-base.txt       # T1 native (core OS)
│   │   ├── 20-shell.txt      # T2 native (CLI/shell)
│   │   ├── 30-desktop.txt    # T3 native (KDE Plasma)
│   │   ├── 40-extras.txt     # T4 native (DMS deps, etc.)
│   │   └── 40-extras.aur.txt # T4 AUR (only AUR list)
│   ├── services/             # Per-tier systemd unit lists
│   │   ├── 10-base.txt       # polkit, NetworkManager, bluetooth, …
│   │   └── 30-desktop.txt    # sddm
│   ├── pkgs.brew.txt         # Homebrew formulae (macOS)
│   └── pkgs.brew-cask.txt    # Homebrew casks (macOS)
├── dots/                     # User dotfiles (symlinked to ~)
│   ├── zsh/                  # .zshrc, .zshenv
│   ├── nvim/                 # LazyVim configuration
│   ├── zathura/              # Zathura PDF viewer config (synctex)
│   └── ...
├── secrets/                  # SOPS-encrypted secrets (committed to repo)
│   ├── opencode.env          # OpenCode MCP API keys
│   ├── vdirsyncer.env        # vdirsyncer OAuth + calendar IDs
│   └── README                # Quick SOPS reference
├── docs/                     # Documentation
│   └── ARCHITECTURE.md       # Design decisions (READ THIS)
├── .sops.yaml                # SOPS encryption rules (age public key)
├── Justfile                  # Task runner commands
└── README.md                 # Main documentation
```

## Code Style Guidelines

### Shell Script Conventions

**Shebang and strict mode** - All scripts MUST start with:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Error handling** - Use trap for cleanup and error reporting:
```bash
trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR
```

**Logging functions** - Use colored output helpers:
```bash
log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
```

**Variable naming**:
- Use `UPPER_SNAKE_CASE` for constants and exported variables
- Use `lower_snake_case` for local variables
- Always quote variables: `"$variable"` not `$variable`

**Script metadata** - Include version at top:
```bash
SCRIPT_VERSION="YYYY-MM-DD-N"
```

### Idempotency Requirements

All scripts MUST be safe to re-run without side effects. Test by running twice.

**Patterns to USE:**
```bash
# Check before acting
if ! systemctl is-enabled bluetooth >/dev/null 2>&1; then
    sudo systemctl enable bluetooth
fi

# Use --needed for pacman (skips already-installed)
sudo pacman -S --needed --noconfirm package-name

# Symlink with backup
if [[ -e "$target" && ! -L "$target" ]]; then
    mv "$target" "${target}.bak"
fi
ln -sf "$source" "$target"
```

**Patterns to AVOID:**
```bash
# BAD: Unbounded append (grows on each run)
echo "something" >> /etc/somefile

# BAD: No idempotency check (errors if already enabled)
sudo systemctl enable bluetooth

# BAD: Partial file edits without markers (may double-apply)
sed -i 's/foo/bar/' /etc/config
```

### Package List Format

Arch native packages live in tier files: `infra/pkgs/10-base.txt`, `20-shell.txt`,
`30-desktop.txt`, `40-extras.txt`. AUR packages have a single tier file
`infra/pkgs/40-extras.aur.txt` (AUR is always T4, regardless of logical grouping).
macOS uses `infra/pkgs.brew.txt` and `infra/pkgs.brew-cask.txt`.

- One package per line
- Comments start with `#`
- Group by section with comment headers
- Alphabetize within sections
- Place packages in the lowest tier whose failure you can tolerate
  (T1 = must work for headless system; T4 = OK if it breaks)

```
# Audio
pipewire
pipewire-pulse
wireplumber

# Development
base-devel
git
```

### Service List Format

Tier files: `infra/services/10-base.txt`, `20-shell.txt`, `30-desktop.txt`, `40-extras.txt`.
- One service per line
- Use full unit names (e.g., `bluetooth.service` or just `bluetooth`)
- Place in the lowest tier whose failure you can tolerate

## Design Principles

1. **No Hidden State** - Every requirement must be in a repo file
2. **Idempotent** - Scripts are safe to re-run
3. **Standard Tools** - pacman, systemd, plain shell, symlinks
4. **Fail Loudly** - Exit on first error with helpful messages

## Key Files Reference

| File                          | Purpose                              |
| ----------------------------- | ------------------------------------ |
| `docs/ARCHITECTURE.md`        | Design decisions (READ FIRST)        |
| `docs/STABILITY.md`           | Failure modes + recovery (boot, NVIDIA, logs) |
| `infra/bootstrap.sh`          | Main system setup script (Arch)      |
| `infra/bootstrap-mac.sh`     | macOS bootstrap (Homebrew)           |
| `infra/doctor.sh`             | System validation                    |
| `infra/fix-boot.sh`           | Boot-entry recovery (system or ISO)  |
| `infra/pkgs/`                 | Tiered Arch package lists (10-base..40-extras) |
| `infra/pkgs/40-extras.aur.txt`| AUR package list (always T4)         |
| `infra/pkgs.brew.txt`         | Homebrew formulae (macOS)            |
| `infra/pkgs.brew-cask.txt`   | Homebrew casks (macOS)               |
| `infra/services/`             | Tiered systemd unit lists            |
| `.sops.yaml`                  | SOPS encryption rules (age key)      |
| `secrets/opencode.env`        | Encrypted OpenCode MCP API keys      |
| `secrets/vdirsyncer.env`      | Encrypted vdirsyncer OAuth + cal IDs |
| `Justfile`                    | Available commands                   |

## Important Notes for AI Agents

1. **This is not a traditional software project** - No package.json, no TypeScript, no unit tests
2. **Validation = doctor.sh** - Use `just doctor` to verify system state
3. **Package lists are authoritative** - Installed packages should match the lists
4. **Scripts use `set -euo pipefail`** - They exit on any error
5. **Do not modify system files directly** - Use the infra scripts
6. **Test by re-running** - Idempotency means second run = no changes
7. **Read ARCHITECTURE.md** - Contains rationale for all design decisions
8. **NEVER execute infra scripts on the dev machine** - Use shellcheck/shfmt for verification
