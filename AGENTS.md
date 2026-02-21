# AGENTS.md - AI Coding Agent Instructions

This document provides instructions for AI coding agents working in the archway repository.

## Development vs Deployment

**CRITICAL**: This repo is developed on dev machines but deployed on target Arch Linux laptops.

- **DO NOT run bootstrap.sh, dotfiles.sh, doctor.sh, or any infra scripts** on the dev machine
- **DO NOT run `just bootstrap`, `just setup`, `just doctor`** - these are for the target laptop
- **Safe to run on dev machine**: `just lint`, `just fmt`, `shellcheck`, `shfmt`
- Scripts require Arch Linux, pacman, systemd, etc. - they will fail on non-Arch systems

When asked to verify changes, use static analysis (shellcheck, shfmt) rather than execution.

## Project Overview

**archway** is a configuration-as-code repository for a reproducible Arch Linux laptop setup.
This is NOT a traditional software project - it contains shell scripts, dotfiles, and package
lists rather than application code.

| Component         | Technology                           |
| ----------------- | ------------------------------------ |
| Primary Language  | Bash shell scripts                   |
| Target OS         | Arch Linux                           |
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
`networkmanager`, `dotfiles`, `snapper`, etc. Run `just checks` for full list.

### Linting and Formatting

```bash
shellcheck infra/*.sh   # Static analysis for shell scripts
shfmt -w infra/*.sh     # Format shell scripts (writes in place)
shfmt -d infra/*.sh     # Show diff without writing (for CI)
```

## Directory Structure

```
archway/
├── infra/                    # System baseline scripts
│   ├── bootstrap.sh          # Main system installer (Arch Linux)
│   ├── bootstrap-mac.sh      # macOS bootstrap (Homebrew + shell)
│   ├── dotfiles.sh           # User dotfile symlinker (cross-platform)
│   ├── doctor.sh             # System validation/health checks
│   ├── pre-bootstrap.sh      # Btrfs snapshot creator
│   ├── pkgs.pacman.txt       # Official repo packages (Arch)
│   ├── pkgs.aur.txt          # AUR packages (Arch)
│   ├── pkgs.brew.txt         # Homebrew formulae (macOS)
│   ├── pkgs.brew-cask.txt    # Homebrew casks (macOS)
│   └── services.system.txt   # systemd services to enable
├── dots/                     # User dotfiles (symlinked to ~)
│   ├── zsh/                  # .zshrc, .zshenv
│   ├── nvim/                 # LazyVim configuration
│   ├── zathura/              # Zathura PDF viewer config (synctex)
│   └── ...
├── docs/                     # Documentation
│   └── ARCHITECTURE.md       # Design decisions (READ THIS)
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

Files: `infra/pkgs.pacman.txt`, `infra/pkgs.aur.txt`, `infra/pkgs.brew.txt`, `infra/pkgs.brew-cask.txt`

- One package per line
- Comments start with `#`
- Group by section with comment headers
- Alphabetize within sections

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

File: `infra/services.system.txt`
- One service per line
- Use full unit names (e.g., `bluetooth.service` or just `bluetooth`)

## Design Principles

1. **No Hidden State** - Every requirement must be in a repo file
2. **Idempotent** - Scripts are safe to re-run
3. **Standard Tools** - pacman, systemd, plain shell, symlinks
4. **Fail Loudly** - Exit on first error with helpful messages

## Key Files Reference

| File                          | Purpose                              |
| ----------------------------- | ------------------------------------ |
| `docs/ARCHITECTURE.md`        | Design decisions (READ FIRST)        |
| `infra/bootstrap.sh`          | Main system setup script (Arch)      |
| `infra/bootstrap-mac.sh`     | macOS bootstrap (Homebrew)           |
| `infra/doctor.sh`             | System validation                    |
| `infra/pkgs.pacman.txt`       | Official package list (Arch)         |
| `infra/pkgs.aur.txt`          | AUR package list (Arch)              |
| `infra/pkgs.brew.txt`         | Homebrew formulae (macOS)            |
| `infra/pkgs.brew-cask.txt`   | Homebrew casks (macOS)               |
| `infra/services.system.txt`   | systemd services                     |
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
