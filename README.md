# archway
Configuration-as-code for a reproducible Arch Linux setup.

Since this a personal setup, it is intentionally and heavily opinionated. 

This repo has not been developed or maintained with a general user in mind. Use it as-is or fork and customize.

Scope: fresh Arch Linux install using systemd, intended for a laptop/desktop workstation.
Design: layered system baseline + user configs, with an optional desktop shell layer.

### Automated installation:

On a fresh Arch/CachyOS install, ensure `curl` and `git` are available first:

```bash
sudo pacman -S --needed curl git
```

Then run one of the following:

```bash
# Default: full install (all 4 tiers, including AUR + DankMaterialShell)
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh)

# Safe: T1+T2+T3 only (skip AUR/DMS/niri — KDE Plasma fallback works)
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) safe

# Minimal: T1+T2 only (headless / CLI only, no GUI)
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) minimal
```

**Recommended for a first run on unfamiliar hardware:** `safe`, verify
boot + login work, then add T4 with `cd ~/archway && just bootstrap-tier 4 && ./install-dms.sh`.

For reproducible installs, pin to a tag:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) --ref v2026.05.03 safe
```

The installer runs in two stages with one reboot. If it doesn't resume automatically, run:

```bash
~/archway/install.sh resume
```


## Overview

archway uses a two-layer model with a tiered system baseline:

| Layer | Tools | Purpose |
|-------|-------|---------|
| **System baseline** | pacman, AUR (yay), systemd | System packages, services, `/etc` config (split into 4 tiers) |
| **User environment** | Shell scripts, dotfile symlinks | CLI tools, shell config, editor setup |

A third optional layer (**DankMaterialShell**) provides the desktop shell experience.

The system baseline is partitioned into four resilience tiers so fragile
components (AUR, DMS) cannot brick the system:

| Tier | Name    | What it installs                                              |
|------|---------|---------------------------------------------------------------|
| 1    | base    | Core OS plumbing: networking, bluetooth, audio, fonts, polkit |
| 2    | shell   | CLI tools, editors, secrets, zsh as default shell             |
| 3    | desktop | KDE Plasma + SDDM (fallback graphical session)                |
| 4    | extras  | AUR packages, DMS, niri, messaging apps (fragile)             |

Tiers run in order; a failed tier stops higher tiers but preserves lower-tier
state. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#tier-model) for details.

See the **[Complete Setup Guide](docs/SETUP.md)** for step-by-step instructions starting from a fresh Arch installation.

## Quick Start (Manual)

```bash
# 1. Clone the repo
git clone https://github.com/Sanchit-Srivastava/archway.git
cd archway

# 2. Run the bootstrap script (installs packages, enables services)
./infra/bootstrap.sh

# 3. Reboot to start SDDM (graphical login)
reboot

# 4. After login, apply user dotfiles
./infra/dotfiles.sh

# 5. (Optional) Install DankMaterialShell for full desktop experience
./install-dms.sh

# 6. Validate the system
./infra/doctor.sh
```

## Directory Structure

```
archway/
├── infra/                    # System baseline layer
│   ├── bootstrap.sh          # Tiered installer (--tier/--up-to/--tiers)
│   ├── dotfiles.sh           # User dotfile symlinker
│   ├── doctor.sh             # System validation
│   ├── pkgs/                 # Per-tier package lists
│   │   ├── 10-base.txt       # T1 native (core OS)
│   │   ├── 20-shell.txt      # T2 native (CLI/shell)
│   │   ├── 30-desktop.txt    # T3 native (KDE Plasma)
│   │   ├── 40-extras.txt     # T4 native (DMS deps, etc.)
│   │   └── 40-extras.aur.txt # T4 AUR (the only AUR list)
│   └── services/             # Per-tier systemd unit lists
│       ├── 10-base.txt       # polkit, NetworkManager, bluetooth, …
│       └── 30-desktop.txt    # sddm
│
├── dots/                     # User dotfiles (symlinked to ~)
│   ├── zsh/                  # Zsh configuration
│   │   ├── .zshrc
│   │   └── .zshenv
│   ├── starship/             # Starship prompt config
│   │   └── starship.toml
│   ├── tmux/                 # Tmux configuration
│   │   └── tmux.conf
│   ├── nvim/                 # Neovim (LazyVim) configuration
│   ├── git/                  # Git configuration
│   │   └── .gitconfig
│   ├── ssh/                  # SSH client configuration
│   │   └── config
│   ├── fastfetch/            # System info display
│   │   └── config.jsonc
│   └── environment.d/        # systemd user session environment
│       └── 50-archway.conf
│
├── docs/                     # Documentation
│   ├── SETUP.md              # Complete setup guide (start here!)
│   └── ARCHITECTURE.md       # Design decisions
│
├── Justfile                  # Task runner commands
└── install-dms.sh            # DankMaterialShell installer
```

## What Gets Installed

### System Packages (via pacman/AUR)

- **Desktop**: niri compositor (via DMS), foot terminal, Nautilus file manager
- **Audio**: PipeWire stack (pipewire, wireplumber, pipewire-pulse)
- **Networking**: NetworkManager, Tailscale, iwd
- **Bluetooth**: bluez, bluetui
- **Authentication**: gnome-keyring, polkit, fprintd (fingerprint)
- **CLI tools**: bat, eza, fd, ripgrep, fzf, zoxide, lazygit, yazi
- **Editor**: Neovim with LSPs (lua, bash, typescript, nix)
- **Fonts**: Noto fonts, Nerd Fonts (JetBrains Mono, Cascadia)
- **Fallback**: KDE Plasma (emergency session if niri/DMS breaks)

### User Configuration (via dotfiles)

- **Shell**: Zsh with oh-my-zsh, autosuggestions, syntax highlighting
- **Prompt**: Starship (minimal, git-aware)
- **Terminal multiplexer**: tmux with vim bindings, TokyoNight theme
- **Editor**: Neovim with LazyVim
- **SSH**: ControlMaster multiplexing, Bitwarden SSH agent integration
- **Git**: Sensible defaults, useful aliases

## Configuration

### Personalizing Git

Edit `dots/git/.gitconfig` and update:

```ini
[user]
    name = Your Name
    email = your@email.com
```

### Personalizing SSH

Edit `dots/ssh/config` to add your hosts.

### Adding Packages

1. Pick the tier:
   - T1 base: core OS (networking, audio, bluetooth, fonts)
   - T2 shell: CLI tools, editors
   - T3 desktop: KDE Plasma, GUI apps
   - T4 extras: AUR-only packages, DMS/niri ecosystem
2. Edit the matching file under `infra/pkgs/` (use `40-extras.aur.txt` for AUR)
3. Re-run `./infra/bootstrap.sh --tier N` (or the full `./infra/bootstrap.sh`)

### Adding Services

1. Edit the matching file under `infra/services/` (usually `10-base.txt`)
2. Re-run `./infra/bootstrap.sh --tier N`

## Maintenance

### Regular Updates

```bash
# Update system packages
sudo pacman -Syu

# Update AUR packages
yay -Syu

# Check for drift (packages installed but not tracked)
./infra/doctor.sh --audit-packages
```

### Using just (task runner)

```bash
just sync       # Pull repo, run bootstrap, validate
just audit      # Check package drift
just doctor     # Run validation checks
```

## Troubleshooting

### Validate System State

```bash
# Run all checks
./infra/doctor.sh

# Run specific check
./infra/doctor.sh --only pipewire

# List available checks
./infra/doctor.sh --list
```

### Common Issues

| Issue | Fix |
|-------|-----|
| No audio | `systemctl --user enable --now pipewire wireplumber` |
| Screen share broken | Check portal: `./infra/doctor.sh --only xdg-portal` |
| Polkit prompts missing | DMS provides polkit agent; ensure DMS is running |
| SSH keys not found | Unlock Bitwarden Desktop, check `SSH_AUTH_SOCK` |

## Recovery

archway does not configure filesystem snapshots by default. If the OS breaks,
reinstall Arch, redeploy this repo, and restore user data from backups.
