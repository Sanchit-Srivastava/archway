# archway

Configuration-as-code for a reproducible Arch Linux laptop setup.

This is a personal setup and is intentionally opinionated. Use it as-is or fork and customize.

Scope: fresh Arch Linux install using systemd, intended for a laptop/desktop workstation.
Design: layered system baseline + user dotfiles, with an optional desktop shell layer.

```bash
curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/install.sh | bash
```

The installer runs in two stages with one reboot. If it doesn't resume automatically, run:

```bash
~/archway/install.sh resume
```

**Philosophy**: Boring, reliable, idempotent. No hidden state.

## Overview

archway uses a two-layer model:

| Layer | Tools | Purpose |
|-------|-------|---------|
| **System baseline** | pacman, AUR (yay), systemd | System packages, services, `/etc` config |
| **User environment** | Shell scripts, dotfile symlinks | CLI tools, shell config, editor setup |

A third optional layer (**DankMaterialShell**) provides the desktop shell experience.

See the **[Complete Setup Guide](docs/SETUP.md)** for step-by-step instructions starting from a fresh Arch installation.

## Quick Start (Manual)

```bash
# 1. Clone the repo
git clone https://github.com/Sanchit-Srivastava/archway.git
cd archway

# 2. (Optional) Create a safety snapshot if on Btrfs
sudo ./infra/pre-bootstrap.sh create

# 3. Run the bootstrap script (installs packages, enables services)
./infra/bootstrap.sh

# 4. Reboot to start SDDM (graphical login)
reboot

# 5. After login, apply user dotfiles
./infra/dotfiles.sh

# 6. (Optional) Install DankMaterialShell for full desktop experience
./install-dms.sh

# 7. Validate the system
./infra/doctor.sh
```

## Directory Structure

```
archway/
├── infra/                    # System baseline layer
│   ├── bootstrap.sh          # Main installer (packages + services)
│   ├── dotfiles.sh           # User dotfile symlinker
│   ├── doctor.sh             # System validation
│   ├── pre-bootstrap.sh      # Btrfs snapshot creator
│   ├── pkgs.pacman.txt       # Official repo packages
│   ├── pkgs.aur.txt          # AUR packages
│   └── services.system.txt   # systemd services to enable
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

1. Edit `infra/pkgs.pacman.txt` (official repos) or `infra/pkgs.aur.txt` (AUR)
2. Re-run `./infra/bootstrap.sh`

### Adding Services

1. Edit `infra/services.system.txt`
2. Re-run `./infra/bootstrap.sh`

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

## Rollback (Btrfs)

If something breaks after bootstrap:

```bash
# List snapshots
snapper list

# Boot into previous snapshot from GRUB menu
# Or rollback manually:
sudo snapper rollback <snapshot-number>
reboot
```

## Philosophy

1. **No hidden state**: Every requirement is encoded in a repo file
2. **Idempotent**: Scripts are safe to re-run
3. **Boring**: Standard tools, minimal magic
4. **Reproducible**: Clone and run to recreate the environment

## License

MIT
