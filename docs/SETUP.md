# Setup Guide

Complete walkthrough for setting up Arch Linux with archway and DankMaterialShell.

**Time estimate**: 45-90 minutes (depending on internet speed and familiarity)

**End result**: A fully configured Arch Linux laptop with:
- niri compositor + DankMaterialShell desktop
- Modern CLI tools (zsh, starship, eza, bat, fzf, etc.)
- PipeWire audio, Bluetooth, NetworkManager
- Btrfs snapshots with GRUB rollback (if using Btrfs)
- Fingerprint authentication (if hardware supports it)

---

## Prerequisites

- Arch Linux ISO (latest from https://archlinux.org/download/)
- Bootable USB drive
- Internet connection (Ethernet recommended for installation, WiFi works too)
- Target laptop/PC with UEFI boot

---

## Part 1: Base Arch Installation (archinstall)

Boot from the Arch ISO and run `archinstall`. Configure these settings:

### 1.1 Language and Locale

| Setting | Value |
|---------|-------|
| Keyboard layout | Your preference (e.g., `us`) |
| Mirror region | Your country |

### 1.2 Disk Configuration

| Setting | Recommended Value |
|---------|-------------------|
| Partitioning | **Best effort default** or manual |
| Filesystem | **btrfs** (required for snapshots, highly recommended) |
| Encryption | **LUKS** (full disk encryption - strongly recommended) |
| Compression | **zstd** (if prompted) |

**Important for Btrfs**: archinstall creates subvolumes automatically. The default layout works with archway's snapper configuration.

If using **manual partitioning** with Btrfs, create these subvolumes:
```
@           → /           (root)
@home       → /home       (user data)
@var_log    → /var/log    (logs)
```

archway's bootstrap will create `@snapshots` automatically if missing.

### 1.3 Bootloader

| Setting | Value |
|---------|-------|
| Bootloader | **GRUB** (required for Btrfs snapshot boot menu) |

systemd-boot works but won't show snapshots in boot menu.

### 1.4 Hostname

| Setting | Value |
|---------|-------|
| Hostname | Your choice (e.g., `archway-laptop`) |

### 1.5 Root Password

| Setting | Value |
|---------|-------|
| Root password | Set a strong password |

### 1.6 User Account

| Setting | Value |
|---------|-------|
| Username | Your username (e.g., `user`) |
| Password | Your password |
| Superuser | **Yes** (adds to wheel group for sudo) |

### 1.7 Profile

| Setting | Value |
|---------|-------|
| Profile | **Minimal** |

Do NOT select a desktop environment - archway handles this.

### 1.8 Audio

| Setting | Value |
|---------|-------|
| Audio | **PipeWire** |

### 1.9 Network Configuration

| Setting | Value |
|---------|-------|
| Network | **NetworkManager** |

### 1.10 Additional Packages

Add these packages in archinstall (optional but saves time):

```
git base-devel
```

### 1.11 Review and Install

1. Review all settings
2. Select **Install**
3. Wait for installation to complete
4. When prompted, select **Yes** to chroot into the new system (or **No** to reboot)

If you didn't chroot, reboot and log in as your user.

---

## Part 2: Clone archway Repository

After booting into your new Arch installation:

### 2.1 Connect to Network (if not already connected)

**Ethernet**: Should work automatically.

**WiFi**:
```bash
# List networks
nmcli device wifi list

# Connect
nmcli device wifi connect "SSID" password "password"
```

### 2.2 Clone the Repository

```bash
# Install git if not installed during archinstall
sudo pacman -S --needed git

# Clone archway to your home directory
cd ~
git clone https://github.com/yourusername/archway.git
cd archway
```

---

## Part 3: System Bootstrap

### 3.1 Create Safety Snapshot (Btrfs only)

If your root filesystem is Btrfs, create a snapshot before making changes:

```bash
# Check if Btrfs
findmnt -n -o FSTYPE /
# Should output: btrfs

# Create pre-bootstrap snapshot (if snapper is configured)
# Skip this on first run - bootstrap will configure snapper
# After first successful run, always do this before major changes:
# sudo ./infra/pre-bootstrap.sh create
```

### 3.2 Run Bootstrap

This installs all packages, enables services, and configures the system:

```bash
./infra/bootstrap.sh
```

**What it does**:
- Installs yay (AUR helper)
- Installs ~100 packages from official repos
- Installs 3 packages from AUR
- Enables system services (NetworkManager, Bluetooth, SDDM, etc.)
- Configures PAM for gnome-keyring auto-unlock
- Configures PAM for fingerprint authentication
- Creates PAM config for DMS lock screen
- Configures XDG portals for niri/Wayland
- Configures SDDM autologin
- Sets up Btrfs snapshots with snapper (if Btrfs)

**Duration**: 10-30 minutes depending on internet speed.

If prompted about pre-bootstrap snapshot, type `y` to continue (first run only).

### 3.3 Reboot

```bash
reboot
```

The system will boot into SDDM (graphical login). With autologin configured, you'll be logged in automatically.

**Note**: At this point, you'll see a basic desktop (likely a black screen or minimal session) because niri/DMS isn't installed yet. This is expected.

If autologin didn't work, log in with your username and password.

---

## Part 4: User Environment Setup

After logging in (you may be in a TTY or minimal graphical session):

### 4.1 Open a Terminal

If in graphical session, press `Ctrl+Alt+F2` to switch to TTY2 and log in there.

### 4.2 Navigate to archway

```bash
cd ~/archway
```

### 4.3 Install Dotfiles

```bash
./infra/dotfiles.sh
```

**What it does**:
- Symlinks zsh configuration (~/.zshrc, ~/.zshenv)
- Symlinks starship prompt config
- Symlinks tmux configuration
- Symlinks neovim configuration (LazyVim)
- Symlinks git configuration
- Symlinks SSH configuration
- Symlinks fastfetch configuration
- Creates bat and GitHub CLI configs
- Symlinks environment.d session variables

### 4.4 Configure Git Identity

**Important**: Edit your git config with your real name and email:

```bash
nvim ~/archway/dots/git/.gitconfig
```

Change these lines:
```ini
[user]
    name = Your Real Name
    email = your.real@email.com
```

### 4.5 Switch to Zsh (if not already)

The bootstrap script sets zsh as default shell, but it takes effect on next login.

```bash
# Start zsh now
zsh

# Oh-my-zsh and plugins will auto-install on first run
# Wait for installation to complete
```

---

## Part 5: Install DankMaterialShell

### 5.1 Run DMS Installer

```bash
cd ~/archway
./install-dms.sh
```

Or run the installer directly:

```bash
curl -fsSL https://install.danklinux.com | sh
```

### 5.2 DMS Installer Options

The DMS installer is interactive. Choose:

| Prompt | Recommended Choice |
|--------|-------------------|
| Compositor | **niri** |
| Terminal | **ghostty**, kitty, or alacritty (your preference) |
| Other options | Follow prompts (defaults are usually fine) |

**What DMS installs**:
- niri compositor
- quickshell (DMS rendering engine)
- DMS shell (panel, launcher, notifications, lock screen)
- matugen (Material You theming)
- Your chosen terminal
- DMS configuration files

### 5.3 Reboot

```bash
reboot
```

---

## Part 6: First Boot with DMS

After reboot, SDDM will auto-login and start niri with DMS.

### 6.1 Verify DMS is Running

You should see:
- A panel/bar at the top or bottom
- Desktop with DMS theming
- Working app launcher (usually Super key)

### 6.2 Open Terminal

- Press the launcher key (usually `Super`) and search for your terminal
- Or use the keybinding configured by DMS

### 6.3 Run Validation

```bash
cd ~/archway
./infra/doctor.sh
```

**Expected output**: Most checks should pass. Some may fail if:
- Not in a graphical session (run from terminal in DMS)
- Some services haven't started yet (try after a few minutes)

Check specific items:
```bash
# List all available checks
./infra/doctor.sh --list

# Run specific check
./infra/doctor.sh --only pipewire
./infra/doctor.sh --only dms
```

---

## Part 7: Post-Installation Configuration

### 7.1 Enroll Fingerprints (Optional)

If your laptop has a fingerprint reader:

```bash
# Enroll fingerprint
fprintd-enroll

# Follow prompts to scan finger multiple times
# Repeat for additional fingers if desired
```

Test fingerprint auth:
```bash
fprintd-verify
```

The DMS lock screen and sudo will now accept fingerprint.

### 7.2 Configure Bitwarden SSH Agent (Optional)

If you use Bitwarden for SSH keys:

1. Install Bitwarden Desktop (available in repos or as Flatpak)
2. Open Bitwarden Desktop
3. Go to **Settings** > **SSH Agent**
4. Enable **SSH Agent**
5. Add your SSH keys to Bitwarden vault (type: SSH Key)

The archway dotfiles already configure `SSH_AUTH_SOCK` to use Bitwarden's socket.

### 7.3 Configure Tailscale (Optional)

If you use Tailscale:

```bash
# Start and authenticate
sudo tailscale up

# Follow the URL to authenticate
```

### 7.4 Set Up Printing (Optional)

Printing services are installed but not enabled by default:

```bash
# Enable CUPS
sudo systemctl enable --now cups

# Enable printer discovery
sudo systemctl enable --now avahi-daemon
sudo systemctl enable --now cups-browsed
```

### 7.5 Configure Firewall (Optional)

UFW is installed but not enabled:

```bash
# Enable firewall with default deny incoming
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

# Allow specific services if needed
sudo ufw allow ssh
```

---

## Part 8: Ongoing Maintenance

### 8.1 System Updates

```bash
# Update all packages
sudo pacman -Syu
yay -Syu

# Or use just
just update
```

### 8.2 Sync archway Changes

If you modify archway (add packages, change configs):

```bash
cd ~/archway
just sync
# Equivalent to: git pull && ./infra/bootstrap.sh && ./infra/dotfiles.sh && ./infra/doctor.sh
```

### 8.3 Package Audit

Check for drift between installed packages and archway lists:

```bash
just audit
# Or: ./infra/doctor.sh --audit-packages
```

### 8.4 Create Snapshot Before Major Changes

```bash
sudo ./infra/pre-bootstrap.sh create
```

### 8.5 Rollback (Btrfs)

If something breaks:

```bash
# List snapshots
snapper list

# Option 1: Boot into snapshot from GRUB menu
# Reboot, select "Arch Linux Snapshots" in GRUB, choose snapshot

# Option 2: Rollback from command line
sudo snapper rollback <snapshot-number>
reboot
```

---

## Troubleshooting

### No Display / Black Screen After Bootstrap

- Press `Ctrl+Alt+F2` to switch to TTY2
- Log in and check if SDDM is running: `systemctl status sddm`
- Check logs: `journalctl -b -p err`

### DMS Not Starting

- Check if niri is installed: `command -v niri`
- Check if quickshell/qs is installed: `command -v qs`
- Try starting niri manually: `niri`
- Check DMS logs: `journalctl --user -u dms`

### No Audio

```bash
# Check PipeWire status
systemctl --user status pipewire wireplumber

# Restart audio stack
systemctl --user restart pipewire wireplumber pipewire-pulse
```

### WiFi Not Working

```bash
# Check NetworkManager
systemctl status NetworkManager

# List networks
nmcli device wifi list

# Connect
nmcli device wifi connect "SSID" password "password"
```

### Bluetooth Not Working

```bash
# Check service
systemctl status bluetooth

# Start if not running
sudo systemctl start bluetooth

# Use bluetui for TUI interface
bluetui
```

### Fingerprint Not Working

```bash
# Check if fprintd is running
systemctl status fprintd

# List enrolled fingerprints
fprintd-list $USER

# Re-enroll if needed
fprintd-delete $USER
fprintd-enroll
```

### Fallback to Plasma

If niri/DMS completely breaks:

1. Press `Ctrl+Alt+F2` to get to TTY
2. Log in
3. Edit SDDM autologin to use Plasma:
   ```bash
   sudo nvim /etc/sddm.conf.d/autologin.conf
   # Change Session=niri to Session=plasma
   ```
4. Or disable autologin and select Plasma from SDDM manually
5. Reboot

---

## Quick Reference

### Key Commands

| Task | Command |
|------|---------|
| Update system | `just update` or `sudo pacman -Syu && yay -Syu` |
| Sync archway | `just sync` |
| Validate system | `just doctor` or `./infra/doctor.sh` |
| Audit packages | `just audit` |
| Create snapshot | `sudo ./infra/pre-bootstrap.sh create` |
| List snapshots | `snapper list` |

### Key Files

| File | Purpose |
|------|---------|
| `~/.zshrc` | Shell configuration (symlink to archway) |
| `~/.config/starship.toml` | Prompt configuration |
| `~/.config/environment.d/50-archway.conf` | Session environment variables |
| `~/.config/environment.d/90-dms.conf` | DMS environment (created by DMS) |
| `/etc/sddm.conf.d/autologin.conf` | SDDM autologin settings |

### Key Directories

| Directory | Purpose |
|-----------|---------|
| `~/archway` | This repository |
| `~/archway/infra/` | System scripts and package lists |
| `~/archway/dots/` | User dotfiles (source of symlinks) |
| `~/.config/` | User configuration (mostly symlinks) |
| `/.snapshots/` | Btrfs snapshots (if using Btrfs) |

---

## Summary: Complete Installation Checklist

- [ ] Boot Arch ISO
- [ ] Run `archinstall` with settings from Part 1
- [ ] Reboot into new system
- [ ] Connect to network
- [ ] Clone archway repo
- [ ] Run `./infra/bootstrap.sh`
- [ ] Reboot
- [ ] Run `./infra/dotfiles.sh`
- [ ] Edit git config with your name/email
- [ ] Run `./install-dms.sh` (choose niri + your terminal)
- [ ] Reboot
- [ ] Run `./infra/doctor.sh` to validate
- [ ] (Optional) Enroll fingerprints
- [ ] (Optional) Configure Bitwarden SSH agent
- [ ] (Optional) Configure Tailscale
- [ ] (Optional) Enable printing services
- [ ] (Optional) Enable firewall
