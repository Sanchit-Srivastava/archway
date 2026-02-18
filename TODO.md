# archway TODO

Running list of tasks to complete for a fully functional Arch Linux desktop with DankMaterialShell + niri.

**Goal**: Bootstrap a reproducible system where running the DMS installer as one of the final steps results in a ready-to-use desktop with all custom configs applied.

---

## Legend

- `[ ]` - Not started
- `[~]` - In progress
- `[x]` - Complete
- `[?]` - Needs investigation/decision

---

## What DMS Installer Handles (DO NOT DUPLICATE)

The DMS `dankinstall` TUI installer handles the following automatically based on user choices:

**Packages it installs:**
- `dms-shell-bin` or `dms-shell-git` (AUR) - the shell itself
- `quickshell-git` (AUR) - rendering engine (v0.2.0+ required)
- `matugen` (pacman) or `matugen-git` (AUR on ARM) - Material You theming
- `dgop` (pacman) - system monitoring backend
- `xdg-desktop-portal-gtk` (pacman) - portal for file dialogs
- `accountsservice` (pacman) - user account D-Bus service
- Compositor: `niri` (pacman) or `niri-git` (AUR) OR `hyprland` (pacman)
- Terminal: `ghostty`, `kitty`, or `alacritty` (user choice)
- niri-specific: `xwayland-satellite` (for X11 app support)
- Hyprland-specific: `jq`

**Configuration it writes:**
- `~/.config/environment.d/90-dms.conf` - sets `TERMINAL` and `ELECTRON_OZONE_PLATFORM_HINT`
- Compositor config (niri or Hyprland) - backs up existing config if present
- Hyprland-only: `~/.config/systemd/user/hyprland-session.target`

**Services it enables:**
- niri: adds `dms` as a want of `niri.service`
- Hyprland: adds `dms` as a want of `hyprland-session.target`

**What DMS provides at runtime:**
- Panel/bar (replaces waybar)
- App launcher (replaces wofi/rofi)
- Notification center (replaces mako/dunst)
- Lock screen with PAM auth (replaces swaylock)
- Polkit authentication agent (replaces polkit-gnome)
- Idle management integration
- Material You dynamic theming
- Clipboard manager
- Control center (WiFi, Bluetooth, audio, displays)

---

## Phase 1: Core System Foundation (archway's responsibility)

These are system-level requirements that must exist BEFORE running DMS installer.

### Packages (already in pkgs.pacman.txt)

- [x] `base-devel` - required for AUR builds
- [x] `git` - required for AUR builds
- [x] `pipewire`, `pipewire-pulse`, `wireplumber` - audio stack
- [x] `bluez`, `bluez-utils` - Bluetooth stack
- [x] `networkmanager` - networking (DMS supports NM, iwd, connman, systemd-networkd)
- [x] `polkit`, `polkit-gnome` - auth prompts (DMS provides its own, but good fallback)
- [x] `gnome-keyring`, `libsecret` - secrets storage
- [x] `fprintd`, `libfprint` - fingerprint auth
- [x] `power-profiles-daemon` - power management
- [x] `xdg-desktop-portal` - portal base
- [x] `sddm` - display manager
- [x] `ufw` - firewall

### Services (already in services.system.txt)

- [x] `bluetooth.service` - DMS uses org.bluez D-Bus interface
- [x] `NetworkManager.service` - DMS uses org.freedesktop.NetworkManager D-Bus
- [x] `power-profiles-daemon.service` - DMS queries power profiles
- [x] `polkit.service` - required for privilege escalation
- [x] `sddm.service` - graphical login

### Services to ADD

- [x] `accounts-daemon.service` - DMS uses org.freedesktop.Accounts for user info/avatar
  - Package `accountsservice` installed by DMS, but service must be enabled
  - Added to `services.system.txt`

### PAM Configuration (already in bootstrap.sh)

- [x] gnome-keyring PAM integration (auto-unlock on login)
- [x] fprintd PAM integration (fingerprint auth)
- [x] DMS lock screen PAM - created `/etc/pam.d/dankshell` with fingerprint support

### D-Bus Interfaces Required (provided by services above)

DMS consumes these D-Bus interfaces - all provided by packages/services we have:

| Interface | Provider | Status |
|-----------|----------|--------|
| `org.bluez` | bluez + bluetooth.service | [x] |
| `org.freedesktop.NetworkManager` | networkmanager + NetworkManager.service | [x] |
| `org.freedesktop.login1` | systemd (built-in) | [x] |
| `org.freedesktop.Accounts` | accountsservice + accounts-daemon.service | [x] |
| `org.freedesktop.portal.Desktop` | xdg-desktop-portal | [x] |
| `org.freedesktop.UPower` | upower (for battery info) | [x] |

---

## Phase 2: Compositor Choice (niri)

DMS installer lets user choose compositor. archway targets niri (no Hyprland fallback).

### Completed

- [x] Removed Hyprland packages (`hyprland`, `hyprpicker`, `hyprsunset`)
- [x] Removed `xdg-desktop-portal-hyprland`
- [x] Removed `foot` terminal
- [x] Added `ghostty` to AUR packages
- [x] Added `xdg-desktop-portal-gnome` for niri screen sharing
- [x] Updated portal config in bootstrap.sh for niri
- [x] **niri dotfiles** - NOT NEEDED: DMS installer creates and manages compositor config
  - DMS backs up any existing config and writes its own
  - niri has sensible built-in defaults for fallback usage without DMS

---

## Phase 3: Packages to Add/Remove

### Completed

- [x] Removed `hyprland`, `hyprpicker`, `hyprsunset`, `foot`
- [x] Removed `xdg-desktop-portal-hyprland`
- [x] Added `xdg-desktop-portal-gnome`
- [x] Added `ghostty` (AUR)

### Add to pkgs.pacman.txt

- [x] `upower` - battery info for DMS
  - Added to POWER MANAGEMENT section

### Terminal

- [x] Using `ghostty` (AUR) - installed by archway, DMS will detect it

---

## Phase 4: Bootstrap.sh Updates

- [x] **Portal configuration** - Updated for niri
  - Uses gnome portal for screen sharing, GTK for file dialogs
  - Already implemented in bootstrap.sh

- [x] **Add accounts-daemon service**
  - Added to `services.system.txt`

- [x] **PAM for DMS lock screen**
  - Created `/etc/pam.d/dankshell` with fingerprint support
  - Falls back to password auth if fingerprint not available

- [x] **Clean up stale Hyprland references**
  - Updated bootstrap.sh polkit messages for DMS
  - Updated next steps instructions

---

## Phase 5: Dotfiles Updates

- [x] **Compositor config** - NOT NEEDED: DMS manages niri/Hyprland config
  - DMS installer creates compositor config with DMS-specific settings
  - Backs up any existing config before writing

- [x] **Environment variables**
  - Created `~/.config/environment.d/50-archway.conf` for base Wayland/XDG settings
  - DMS writes `~/.config/environment.d/90-dms.conf` (loaded after archway's)
  - Keeps settings separate to avoid conflicts

---

## Phase 6: Shell Configuration (omarchy-inspired)

Replicate omarchy's terminal experience with zsh, Starship prompt, and modern CLI tools.

### Shell Choice

- [x] **Use zsh as primary shell** (already configured in archway)
  - Better completion, shared history, oh-my-zsh ecosystem
  - All omarchy tools work with zsh

### Packages (pkgs.pacman.txt) - COMPLETED

#### Core CLI Productivity Tools

- [x] `starship` - cross-shell prompt with minimal config
- [x] `zoxide` - smart cd command with frecency tracking
- [x] `eza` - modern ls replacement with icons and git integration
- [x] `bat` - modern cat with syntax highlighting
- [x] `fd` - modern find replacement
- [x] `fzf` - fuzzy finder for files/history
- [x] `ripgrep` - modern grep replacement
- [x] `dust` - disk usage analyzer (modern du)
- [x] `less` - pager

#### Development Tools

- [x] `lazygit` - terminal UI for git
- [x] `jq` - JSON processor
- [x] `github-cli` - GitHub CLI (`gh` command)

#### TUI Applications

- [x] `btop` - system monitor (modern htop)
- [x] `fastfetch` - system information display

#### Terminal Multiplexer

- [x] `tmux` - terminal multiplexer

#### Utilities

- [x] `plocate` - fast file locator

#### Not Added (optional)

- [ ] `tldr` - simplified man pages (optional)
- [ ] `gum` - interactive shell scripting tool (optional)
- [ ] `lazydocker` - terminal UI for docker (only if docker used)

### Dotfiles - COMPLETED

#### Starship Prompt (`dots/starship/starship.toml`)

- [x] Created starship config (omarchy-style minimal cyan theme)
  - Shows directory (truncated), git branch, git status
  - Success/error symbols: `❯` / `✗`
  - Symlinked to `~/.config/starship.toml`

#### Zsh Configuration (`dots/zsh/`)

- [x] `.zshrc` - main config with:
  - Self-bootstrapping oh-my-zsh + plugins
  - Tool integrations (starship, zoxide, fzf)
  - Modern CLI aliases (eza, bat, ripgrep, fd, dust)
  - Git aliases
  - History configuration
  - Local override support (`.zshrc.local`)

- [x] `.zshenv` - environment variables:
  - EDITOR=nvim
  - Wayland env vars
  - XDG base directories
  - Bitwarden SSH agent socket

#### Tmux Configuration (`dots/tmux/tmux.conf`)

- [x] Created tmux config with:
  - Prefix: `Ctrl+a`
  - Vi mode for copy
  - Mouse enabled
  - TokyoNight Moon theme
  - Vim-style pane navigation

#### Git Configuration (`dots/git/.gitconfig`)

- [x] Git config with:
  - Aliases (st, co, br, ci, lg, unstage, last)
  - pull.rebase = true
  - push.autoSetupRemote = true
  - rebase.autoStash = true

#### Other Configs - COMPLETED

- [x] Fastfetch config (`dots/fastfetch/config.jsonc`)
- [x] Bat config (created by dotfiles.sh)
- [x] GitHub CLI config (created by dotfiles.sh)

### dotfiles.sh Symlinks - COMPLETED

- [x] `~/.config/starship.toml` -> `dots/starship/starship.toml`
- [x] `~/.config/tmux/tmux.conf` -> `dots/tmux/tmux.conf`
- [x] `~/.gitconfig` -> `dots/git/.gitconfig`
- [x] `~/.config/fastfetch/config.jsonc` -> `dots/fastfetch/config.jsonc`

---

## Phase 7: Doctor.sh Updates

- [x] **Update for niri + DMS**
  - Replaced Hyprland checks with niri checks
  - Added `check_niri_installed` - checks for niri compositor
  - Added `check_accounts_daemon` - checks accounts-daemon service
  - Added `check_dms_installed` - checks for quickshell/qs
  - Updated portal configuration check to look for gnome instead of hyprland
  - Updated polkit agent check message
  - Updated help text with new check IDs

- [x] **Add shell tool checks**
  - Added checks for: starship, zoxide, eza, bat, fzf, fd, ripgrep, lazygit
  - Added checks for: starship-config, environment-d (dotfile symlinks)
  - Updated tap_plan count from 26 to 37

---

## Phase 8: Documentation

- [x] **Update README.md**
  - Document niri + DMS workflow
  - Update Quick Start for DMS installer step
  - Fixed Hyprland → niri references

- [x] **Update ARCHITECTURE.md**
  - Update layer diagram to show DMS as third layer
  - Document what archway provides vs what DMS provides
  - Document compositor choice
  - Removed incorrect compositor dotfiles reference from User Environment layer

---

## Open Questions

1. ~~**Keep Hyprland as fallback?**~~ **DECIDED: No** - Removed Hyprland packages

2. ~~**Terminal choice?**~~ **DECIDED: ghostty** - Added to AUR packages

3. ~~**Shell choice?**~~ **DECIDED: zsh** - Better completion, already configured, oh-my-zsh ecosystem

4. **Portal backend for niri?**
   - Using `xdg-desktop-portal-gnome` for screen sharing
   - Need to test this works correctly

5. **Greeter/Login?**
   - Current: SDDM
   - Alternative: greetd + DMS greeter module
   - Recommendation: Keep SDDM for simplicity

6. **Autologin?** **DECIDED: Yes** - Implemented in bootstrap.sh
   - User has full disk encryption (FDE), so machine is protected at boot
   - Faster boot, keyring auto-unlock works better
   - `configure_sddm_autologin()` creates `/etc/sddm.conf.d/autologin.conf`

---

## Installation Flow

1. **Boot Arch ISO, install base system**
2. **Clone archway repo**
3. **Run `./infra/pre-bootstrap.sh create`** (safety snapshot)
4. **Run `./infra/bootstrap.sh`** (packages, services, PAM, portals)
5. **Reboot into SDDM**
6. **Login, run `./infra/dotfiles.sh`** (user configs)
7. **Run DMS installer**: `curl -fsSL https://dms.avenge.cloud | bash`
   - Choose compositor: niri
   - Choose terminal: ghostty/kitty/alacritty
   - Installer handles DMS packages and config
8. **Reboot or re-login**
9. **Run `./infra/doctor.sh`** (validate everything)

---

## Reference

- [DankMaterialShell repo](https://github.com/AvengeMedia/DankMaterialShell)
- [niri repo](https://github.com/niri-wm/niri)
- [omarchy repo](https://github.com/basecamp/omarchy)
- [Quickshell repo](https://github.com/quickshell-mirror/quickshell)
