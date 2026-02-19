# Architecture

archway is a configuration-as-code setup for a single Arch Linux workstation.
It is intentionally opinionated and optimized for reproducibility over flexibility.

## Scope

- Target: fresh Arch Linux install using systemd
- Audience: single-user laptop/desktop workstation
- Not a general-purpose distro installer

## Layered Model

archway uses three layers with clear ownership boundaries:

```
┌─────────────────────────────────────────────────────────────────┐
│                     DESKTOP SHELL                               │
│  DankMaterialShell (installed by its installer)                 │
│  Scope: Panel, launcher, notifications, lock screen, theming    │
│  Installs: shell, compositor, terminal, theming stack           │
├─────────────────────────────────────────────────────────────────┤
│                     USER ENVIRONMENT                            │
│  dots/* → ~/.config/*, ~/.zshrc, ~/.gitconfig, etc.             │
│  Scope: Shell, editor, CLI tools, user preferences              │
├─────────────────────────────────────────────────────────────────┤
│                     SYSTEM BASELINE                             │
│  pacman + AUR + systemd + /etc                                  │
│  Scope: Packages, services, PAM, portals, D-Bus providers       │
└─────────────────────────────────────────────────────────────────┘
```

### System Baseline

- Installs packages and enables services
- Configures PAM, portals, and system-wide settings
- Ensures D-Bus providers for desktop shell integrations

### User Environment

- Symlinks dotfiles into the home directory
- Manages shell/editor/CLI defaults

### Desktop Shell (DMS)

- Installs the compositor and shell components
- Owns its configuration and update flow
- Provides the graphical shell experience

## Idempotency

All scripts are safe to re-run. Package installs use `--needed`, services are checked before enabling,
and dotfiles use symlink-with-backup behavior.

## Package Lists

- `infra/pkgs.pacman.txt` for official packages
- `infra/pkgs.aur.txt` for AUR packages

## Services

- `infra/services.system.txt` is the source of truth for system services

## Dotfiles

- `infra/dotfiles.sh` symlinks all files from `dots/` into `~/`
- Edits should be made in `dots/` and will reflect immediately
