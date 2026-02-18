# Architecture

This document describes the design decisions behind archway.

## Layered Model

archway uses a strict three-layer ownership model:

```
┌─────────────────────────────────────────────────────────────────┐
│                     DESKTOP SHELL                               │
│  DankMaterialShell (installed via dankinstall TUI)             │
│  Owner: DMS installer (curl -fsSL https://dms.avenge.cloud)    │
│  Scope: Panel, launcher, notifications, lock screen, theming   │
│  Installs: quickshell, matugen, dgop, compositor, terminal     │
├─────────────────────────────────────────────────────────────────┤
│                     USER ENVIRONMENT                            │
│  dots/* → ~/.config/*, ~/.zshrc, ~/.gitconfig, etc.            │
│  Owner: infra/dotfiles.sh (symlinks)                           │
│  Scope: Shell, editor, CLI tools, user preferences             │
├─────────────────────────────────────────────────────────────────┤
│                     SYSTEM BASELINE                             │
│  pacman + AUR + systemd + /etc                                 │
│  Owner: infra/bootstrap.sh                                     │
│  Scope: Packages, services, PAM, portals, D-Bus providers      │
└─────────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

**System Baseline (archway)** provides:
- D-Bus service providers (bluetooth, NetworkManager, accountsservice, etc.)
- System services (systemd units)
- PAM configuration (login, keyring, fingerprint)
- XDG portal base configuration
- Audio stack (PipeWire)
- Base packages for development and CLI tools

**User Environment (archway)** provides:
- Shell configuration (zsh, starship)
- Editor configuration (neovim)
- Git configuration
- SSH configuration

**Desktop Shell (DMS)** provides:
- Visual shell components (panel, dock, launcher)
- Notification system
- Lock screen with PAM integration
- Polkit authentication agent
- Material You dynamic theming
- Compositor (niri or Hyprland) - installed by DMS
- Terminal emulator (ghostty/kitty/alacritty) - installed by DMS
- Rendering engine (quickshell)

### Why This Split?

**System baseline** handles things that:
- Require root access
- Are system-wide (affect all users)
- Integrate with systemd/PAM/udev
- Need to work before user login
- Provide D-Bus interfaces that DMS consumes

**User environment** handles things that:
- Are user-specific preferences
- Can be managed with symlinks
- Don't require root
- Are portable across machines

**Desktop shell (DMS)** handles things that:
- Are visual/interactive desktop components
- Have their own installation and update mechanism
- Need tight integration between multiple components
- Benefit from unified theming

### What NOT to Duplicate

DMS installer handles these - do NOT add to archway package lists:
- `quickshell` / `quickshell-git` - DMS rendering engine
- `matugen` / `matugen-git` - Material You theming
- `dgop` - DMS system monitoring backend
- `dms-shell-bin` / `dms-shell-git` - DMS itself
- `niri` / `hyprland` - compositor (user chooses in DMS installer)
- `ghostty` / `kitty` / `alacritty` - terminal (user chooses in DMS installer)
- `xwayland-satellite` - X11 support for niri

### What NOT to Mix

| Don't | Why |
|-------|-----|
| User dotfiles in /etc | Not portable, requires root |
| System services in user config | Won't start before login |
| PAM config via dotfiles | Requires root, affects login |
| DMS packages in archway | DMS installer manages them |

## D-Bus Service Requirements

DMS consumes several D-Bus interfaces. archway must ensure the providers are installed and running.

| D-Bus Interface | Provider Package | Service | Purpose |
|-----------------|------------------|---------|---------|
| `org.bluez` | `bluez` | `bluetooth.service` | Bluetooth control |
| `org.freedesktop.NetworkManager` | `networkmanager` | `NetworkManager.service` | WiFi/network control |
| `org.freedesktop.login1` | `systemd` | (built-in) | Session control, suspend, lock |
| `org.freedesktop.Accounts` | `accountsservice` | `accounts-daemon.service` | User info, avatar |
| `org.freedesktop.UPower` | `upower` | `upower.service` | Battery status (optional) |
| `org.freedesktop.portal.*` | `xdg-desktop-portal*` | `xdg-desktop-portal.service` | File dialogs, screen share |

DMS also implements:
- `org.freedesktop.ScreenSaver` - for media player inhibition

## Idempotency

All scripts must be safe to re-run without side effects.

### Patterns to Use

```bash
# Good: Check before acting
if ! systemctl is-enabled bluetooth >/dev/null 2>&1; then
    sudo systemctl enable bluetooth
fi

# Good: Use --needed for pacman
sudo pacman -S --needed package-name

# Good: Atomic file replacement
sudo install -D -m 0644 source /etc/target

# Good: Symlink with backup
if [[ -e "$target" && ! -L "$target" ]]; then
    mv "$target" "${target}.bak"
fi
ln -sf "$source" "$target"
```

### Patterns to Avoid

```bash
# Bad: Unbounded append
echo "something" >> /etc/somefile

# Bad: No idempotency check
sudo systemctl enable bluetooth  # Errors if already enabled

# Bad: Partial file edits without markers
sed -i 's/foo/bar/' /etc/config  # May double-apply
```

## Package Management

### Registry Files

Packages are tracked in plain text files:

- `infra/pkgs.pacman.txt` - Official Arch repos
- `infra/pkgs.aur.txt` - AUR packages

**Format**:
- One package per line
- Comments start with `#`
- Grouped by section with comment headers
- Alphabetized within sections

### Drift Detection

`./infra/doctor.sh --audit-packages` compares:
- Explicitly installed packages vs. registry files
- Reports untracked packages (installed but not in repo)
- Reports missing packages (in repo but not installed)

## Dotfile Management

### Directory Structure

```
dots/
├── zsh/
│   ├── .zshrc      → ~/.zshrc
│   └── .zshenv     → ~/.zshenv
├── starship/
│   └── starship.toml → ~/.config/starship.toml
├── nvim/           → ~/.config/nvim (whole directory)
└── ...
```

### Symlink Strategy

`infra/dotfiles.sh` creates symlinks from `~` to `dots/`:

1. Check if target exists
2. If regular file, backup to `.bak`
3. If symlink pointing elsewhere, remove
4. Create symlink

**Why symlinks over copies?**
- Edits in `~` are immediately visible in repo
- `git diff` shows changes
- No sync step needed

### Self-Bootstrapping Shell Config

The `.zshrc` auto-installs missing components:

```bash
# Auto-install oh-my-zsh if missing
if [[ ! -d "$ZSH" ]]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH"
fi

# Auto-install plugins if missing
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
```

This ensures the shell works even on first run, without requiring a separate install step.

## Neovim / LazyVim

### LSP Installation Strategy

Two options for language servers:

| Approach | Location |
|----------|----------|
| System packages | `infra/pkgs.pacman.txt` |
| Mason.nvim | Auto-installed by LazyVim on first use |

**Current approach**: Both.
- Critical LSPs in pacman (lua-language-server, bash-language-server)
- Mason as fallback for others

**Rationale**: System packages are reproducible and tracked. Mason provides convenience for languages not in repos.

## SSH Agent: Bitwarden

archway uses Bitwarden Desktop as the SSH agent instead of ssh-agent or gnome-keyring.

**Configuration**:
```bash
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
```

**Why Bitwarden?**
- SSH keys stored in password manager (encrypted, synced)
- No separate key files to manage
- Works across machines via Bitwarden sync

**Setup**:
1. Enable SSH Agent in Bitwarden Desktop settings
2. Add SSH keys to Bitwarden vault (type: SSH Key)
3. Unlock Bitwarden when you need SSH access

## Btrfs Snapshots

If the root filesystem is Btrfs with proper subvolume layout, archway configures snapper for automatic snapshots.

### Expected Subvolume Layout

```
/@           → /
/@home       → /home
/@snapshots  → /.snapshots
/@var_log    → /var/log
```

### Snapshot Schedule

- Hourly snapshots (keep 5)
- Daily snapshots (keep 7)
- Weekly snapshots (keep 4)
- Monthly snapshots (keep 2)

### GRUB Integration

`grub-btrfs` adds snapshots to GRUB boot menu for easy rollback.

## Fallback Sessions

archway provides fallback options if the primary desktop breaks:

### KDE Plasma (Emergency Fallback)

Minimal Plasma packages for emergency recovery:
```
plasma-desktop plasma-nm plasma-pa kscreen bluedevil
```

Select "Plasma (Wayland)" from SDDM if niri/DMS fails to start.

### niri Without DMS

If DMS breaks but niri works:
- niri has built-in minimal functionality (window management, basic keybindings)
- Can launch apps via keybindings defined in niri config
- ghostty terminal available for CLI access

The fallback flow:
1. Try primary: niri + DMS
2. If DMS fails: niri alone (functional but minimal)
3. If niri fails: Plasma Wayland
4. If Plasma fails: TTY login (always available)

## DankMaterialShell Integration

DMS is a complete desktop shell that replaces traditional components:

| Traditional | DMS Replacement |
|-------------|-----------------|
| waybar | DMS TopBar/DankBar |
| wofi/rofi | DMS Spotlight launcher |
| mako/dunst | DMS Notifications |
| swaylock/hyprlock | DMS Lock screen |
| polkit-gnome | DMS PolkitAgent |
| swayidle/hypridle | DMS IdleService |

### Installation Flow

1. archway bootstrap installs system baseline (D-Bus providers, services, PAM)
2. archway dotfiles installs user preferences (shell, editor, git)
3. DMS installer (`curl -fsSL https://dms.avenge.cloud | bash`) installs:
   - Compositor (niri or Hyprland) - user choice
   - Terminal (ghostty/kitty/alacritty) - user choice
   - DMS shell and dependencies
   - Environment config (`~/.config/environment.d/90-dms.conf`)
   - systemd user service integration

### PAM Integration

DMS lock screen uses PAM for authentication. It checks for:
1. `/etc/pam.d/dankshell` (custom config)
2. Falls back to `/etc/pam.d/login`

For fingerprint support in DMS lock screen, ensure fprintd is configured in the PAM stack.

### Compositor Configuration

archway targets niri as the compositor. DMS installs and configures niri during its setup.

**DMS handles compositor config entirely:**
- Installs niri (or Hyprland) based on user choice
- Creates compositor config with DMS-specific settings
- Backs up any existing config before writing
- Manages keybindings, input settings, and output settings

**archway does NOT provide compositor dotfiles** because:
- DMS needs specific config for its shell integration
- DMS backs up and replaces any existing config anyway
- niri has sensible built-in defaults for fallback usage without DMS

DMS handles:
- Starting its own services via systemd user units
- Autostart of shell components
- Session integration (adds itself as a want of `niri.service`)

**Why separate installer?** DMS is actively developed with its own release cycle. Using their installer ensures:
- Correct version compatibility between components
- Proper AUR package ordering (quickshell before dms-shell)
- Configuration that matches DMS expectations

## Design Principles

### 1. No Hidden State

Every requirement must be encoded in a repo file:
- Package needed? Add to `pkgs.pacman.txt`
- Service needed? Add to `services.system.txt`
- Config needed? Add to `dots/`

**Anti-pattern**: "I installed X manually" or "Remember to run Y"

### 2. Prefer Standard Tools

- pacman over custom package managers
- systemd over init scripts
- Plain shell over frameworks
- Symlinks over copy scripts

### 3. Fail Loudly

Scripts should:
- Exit on first error (`set -e`)
- Print what went wrong
- Suggest the fix
- Reference the repo file to update

### 4. Test via Re-run

The test for idempotency: run the script twice.
- First run: makes changes
- Second run: no changes (or harmless no-ops)

## File Reference

| File | Purpose |
|------|---------|
| `infra/bootstrap.sh` | System setup (packages, services, PAM, portals) |
| `infra/dotfiles.sh` | Symlink user dotfiles |
| `infra/doctor.sh` | Validate system state |
| `infra/pre-bootstrap.sh` | Create safety snapshot |
| `infra/pkgs.pacman.txt` | Official repo packages |
| `infra/pkgs.aur.txt` | AUR packages |
| `infra/services.system.txt` | systemd services |
| `dots/*` | User dotfiles |
| `Justfile` | Task runner commands |
