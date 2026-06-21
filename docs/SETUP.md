# Setup Guide

Complete walkthrough for setting up Arch Linux with archway and DankMaterialShell.

This is a personal setup and is intentionally opinionated. Use it as-is or fork and customize.

Scope: fresh Arch Linux install using systemd, intended for a laptop/desktop workstation.
Design: layered system baseline + user dotfiles, with an optional desktop shell layer.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh)
```

The installer runs in two stages with **one reboot**.

**Autostart resume is unreliable.** After reboot and logging into a graphical session, **always run**:

```bash
~/archway/install.sh resume
```

This is the reliable way to continue (you will see this reminder at the end of Stage 1).

### Install profiles

`install.sh` accepts `--profile` to control how much of the system is installed.
This maps directly to the [tier model](ARCHITECTURE.md#tier-model):

| Profile   | Tiers   | Includes                                            |
| --------- | ------- | --------------------------------------------------- |
| `minimal` | T1+T2   | Headless: base + shell, no GUI                      |
| `safe`    | T1+T2+T3 | Adds KDE Plasma fallback (no AUR/DMS). TeX is intentionally excluded from tiers — install later with `just tex` if needed. |
| `full`    | T1-T4   | Adds AUR + DankMaterialShell (default)              |

Examples:
```bash
~/archway/install.sh --profile minimal   # headless server-style install
~/archway/install.sh --profile safe      # robust desktop, no fragile AUR
~/archway/install.sh                     # equivalent to --profile full
```

**Time estimate**: 45-90 minutes (depending on internet speed and familiarity)

**End result**: A fully configured Arch Linux laptop with:
- niri compositor + DankMaterialShell desktop
- Modern CLI tools (zsh, starship, eza, bat, fzf, etc.)
- PipeWire audio, Bluetooth, NetworkManager
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
| Filesystem | **ext4** |
| Encryption | **LUKS** (full disk encryption - strongly recommended) |
| Compression | Not applicable |

archway no longer configures Btrfs snapshots by default. The recommended
recovery model is: reinstall Arch with the same simple ext4 + LUKS defaults,
redeploy this repo, then restore user data from backups.

> **Before reinstalling, check [docs/STABILITY.md](STABILITY.md).** The two
> problems that look like "I must reinstall" — a **vanished boot entry** (drops
> to BIOS) and a **graphics/KWin crash loop** — are both quick fixes
> (`just fix-boot`; or use the Plasma X11 session) that do **not** require
> reinstalling. Reinstall is the last resort, not the first.

### 1.3 Bootloader

| Setting | Value |
|---------|-------|
| Bootloader | **systemd-boot** (UEFI; ships with `systemd`, no extra package) |

archway standardizes on systemd-boot, which archinstall installs automatically
when you select it above. Bootstrap does **not** re-run `bootctl` — archinstall
already installed it and registered the EFI entry correctly.

**Why systemd-boot:**
- Zero AUR dependencies (no GraalVM/Gradle build chain)
- Auto-detects Windows Boot Manager for dual-boot
- Default and recommended bootloader on CachyOS
- Trivial to recover from scripts if NVRAM is wiped

If the firmware ever "forgets" the boot entry (boots straight to BIOS), do not
reinstall — run `just fix-boot` (from the system or the Arch ISO). See
[docs/STABILITY.md](STABILITY.md#1-boot-entry-vanished-drops-to-bios).

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
| Profile type | **Desktop** |
| Desktop environment | **KDE Plasma** |
| Login manager | **SDDM** (default for KDE) |
| Greeter / extras | Accept the profile defaults |

**Why KDE Plasma is the canonical archway baseline:**

archway's Tier 4 (T4) layer installs DankMaterialShell + niri as the daily-driver
session. T4 is allowed to break — by design. The KDE Plasma session is the
**always-working fallback**: if niri/DMS fails to start, you log into Plasma
from SDDM and have a fully functional graphical desktop, browser, file manager,
network manager, and bluetooth UI.

Picking the KDE Plasma profile in archinstall (instead of "Minimal") gives us
this fallback for free, with the distro's blessed package set. archway then
**layers on top** — it does not re-install Plasma. Specifically:

- `infra/pkgs/30-desktop.txt` lists only what archway *adds* on top of
  `plasma-meta` (the metapackage installed by the archinstall KDE profile).
  Anything provided by `plasma-meta` is omitted from that list.
- `infra/doctor.sh --audit-packages` knows about the `plasma-meta` baseline
  and will not flag those packages as "untracked".
- `infra/dotfiles.sh` deploys `~/.config/autostart/kwalletd6.desktop` with
  `Hidden=true` to disable KWallet — archway uses gnome-keyring as its single
  Secret Service provider, and the two daemons race for the same D-Bus name.

Do NOT select any *additional* desktop environment alongside Plasma.

### 1.8 Audio

| Setting | Value |
|---------|-------|
| Audio | **PipeWire** |

### 1.9 Network Configuration

| Setting | Value |
|---------|-------|
| Network | **NetworkManager** |

### 1.10 Additional Packages and Reusing Configuration

#### Additional packages during a fresh install

Archinstall has an "**Additional packages**" (or "Write additional packages to install") step. This is a text input where you can paste a list of package names (space or newline separated). It also shows search results from the huge available list as you type.

To get a ready-to-paste list for a **full working system without the heavy LaTeX parts** (recommended for your first fresh install):

1. Have the `archway` repo available in the live environment (pre-copy it to your Ventoy data partition before booting the ISO — see guide below).
2. Generate the list:
   ```bash
   ./infra/list-additional-packages.sh --up-to 3 > /tmp/archway-pkgs.txt
   cat /tmp/archway-pkgs.txt
   ```
3. In archinstall's Additional packages prompt, paste the contents of the file.

**LaTeX/TeX is intentionally excluded** from the main tiers and the default package list (see below).

#### Saving and Reusing Your archinstall Configuration (Recommended for Ventoy Users)

Your installs are nearly identical every time — only the target disk and hostname change. Archinstall supports saving a full declarative configuration so you don't repeat the menus.

**During this fresh installation (first time):**

1. **Before booting the ISO**: Copy the `archway` directory to the **data/persistent partition** of your Ventoy USB (this area survives boots and holds files alongside your ISOs).

2. Boot the Arch ISO via Ventoy.

3. In the live environment, mount the Ventoy data partition and enter the repo:
   ```bash
   lsblk -f                          # identify the Ventoy data partition
   mount /dev/sdXN /mnt/ventoy       # replace sdXN with the correct device
   cd /mnt/ventoy/archway
   ```

4. Generate the additional packages list for a full working system (no TeX):
   ```bash
   ./infra/list-additional-packages.sh --up-to 3 > /tmp/archway-pkgs.txt
   cat /tmp/archway-pkgs.txt
   ```

5. Run the guided installer:
   ```bash
   archinstall
   ```
   - Choose your usual settings:
     - Disk: Best effort default + ext4 + LUKS (full disk encryption, no separate `/home` recommended).
     - Bootloader: systemd-boot.
     - Profile: Desktop → KDE Plasma.
     - Network: NetworkManager.
   - At the **Additional packages** prompt: paste the list from `/tmp/archway-pkgs.txt`.
   - Complete the rest of the wizard (users, timezone, etc.).

6. **Save the configuration** (critical step):
   - Near the end (before the final "Install" confirmation), archinstall offers a "Save configuration" option.
   - First create the target directory on the Ventoy data partition:
     ```bash
     mkdir -p /mnt/ventoy/archway/configs
     ```
   - Save `user_configuration.json` (and `user_credentials.json` if it asks) directly there:
     ```
     /mnt/ventoy/archway/configs/user_configuration.json
     /mnt/ventoy/archway/configs/user_credentials.json
     ```
   - Proceed with the installation.

7. After the system is installed and you have rebooted (or from the live environment), ensure the two JSON files are on the Ventoy data partition in the `configs/` directory (copy them from the new installation if you saved them elsewhere).

8. Continue with the normal post-install steps (`just bootstrap`, `just dotfiles`, etc.).

**For all future reinstalls:**

1. Boot the Arch ISO via Ventoy.

2. Mount the Ventoy data partition:
   ```bash
   mount /dev/sdXN /mnt/ventoy
   ```

3. Reuse the saved configuration:
   ```bash
   archinstall --config /mnt/ventoy/archway/configs/user_configuration.json \
               --creds   /mnt/ventoy/archway/configs/user_credentials.json
   ```

4. archinstall will pre-fill almost everything (disk layout style, LUKS, profile, packages, bootloader, etc.).

5. You will still be prompted for the varying items:
   - The specific target disk device.
   - Hostname.
   - Any user details not fully saved in the creds file.

6. Review the summary and proceed with the install.

7. After first boot into the new system:
   - Connect to the network.
   - Clone/update the archway repo if needed.
   - Run `just bootstrap` (or your preferred profile). Many packages will already be present, so this step will be much faster.
   - Run `just dotfiles`, etc.
   - Add LaTeX later with `just tex` when convenient.

**Keeping the additional packages list up to date**

When the tier lists in the repo change (new packages added/removed):

```bash
cd /mnt/ventoy/archway
./infra/list-additional-packages.sh --up-to 3 > /tmp/new-pkgs.txt
```

Edit the saved `user_configuration.json` and update the `"packages"` array with the new list (JSON array format). You can do this on any machine with the repo.

**LaTeX / TeX parts**

The heavy TeX Live packages (and biber, python-pynvim for vimtex) have been moved out of the main tier lists. A full working system installed via archinstall + bootstrap (or the reused config) will **not** include LaTeX by default.

To add it on demand (after you have a working system and better connectivity):

```bash
just tex
# or directly
./infra/install-tex.sh
```

This is exactly what you asked for: the whole working system without the LaTeX parts in the main installation.

### 1.11 Review and Install

1. Review all settings
2. Select **Install**
3. Wait for installation to complete
4. When prompted, select **Yes** to chroot into the new system (or **No** to reboot)

If you didn't chroot, reboot and log in as your user.

---

## Part 2: Clone archway Repository (Manual)

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
git clone https://github.com/Sanchit-Srivastava/archway.git
cd archway
```

---

## Part 3: System Bootstrap

### 3.1 Run Bootstrap

This installs all packages, enables services, and configures the system:

```bash
./infra/bootstrap.sh
```

**What it does**:
- Installs yay (AUR helper)
- Installs baseline packages from official repos (per tier lists)
- Installs configured AUR packages when using the full profile
- Enables system services (NetworkManager, Bluetooth, etc.)
- Deploys the keyd keyboard remapping config
- Sets zsh as the default shell
- Configures SDDM autologin (into niri if present, otherwise Plasma) — best-effort; resume command always works

**Duration**: 10-30 minutes depending on internet speed.

### 3.2 Reboot

```bash
reboot
```

The system will boot into SDDM (graphical login). With autologin configured, you'll be logged in automatically.

At this point, you'll see a basic desktop (likely a black screen or minimal session) because niri/DMS isn't installed yet. This is expected.

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

### 4.3 Set Up Secrets Decryption

`dotfiles.sh` automatically creates an empty age key file at
`~/.config/sops/age/keys.txt` on first run. Without a key, it creates empty
templates for secrets files — you'll fill them in later.

After the desktop is running and Bitwarden is available (Part 6+):

```bash
# Open the empty key file that dotfiles.sh created
nvim ~/.config/sops/age/keys.txt

# Paste the full contents from your Bitwarden secure note:
#   # created: 2025-...
#   # public key: age1...
#   AGE-SECRET-KEY-...
# Save and close.

# Re-run dotfiles to decrypt secrets from the repo
just dotfiles
```

If you forked this repo and don't have the age key, skip this step entirely.
The empty templates created during step 4.4 work fine — fill in values manually.

### 4.4 Install Dotfiles

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
- Decrypts secrets from repo (SOPS + age) or creates empty templates

### 4.5 Configure Git Identity

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

### 4.6 Switch to Zsh (if not already)

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

### 6.4 Post-DMS Customization

If you installed DMS manually, apply archway's DMS customizations after DMS has started once:

```bash
cd ~/archway
./infra/post-dms-install.sh
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

KDE's lock screen and DMS's lock screen will now accept fingerprint. To also
unlock `sudo` and console login, add one line to `/etc/pam.d/system-auth` —
see [docs/STABILITY.md](STABILITY.md#fingerprint-fprintd) for the exact
one-time step and the safety warning about keeping a root shell open while
testing.

### 7.2 Configure Bitwarden SSH Agent (Optional)

If you use Bitwarden for SSH keys:

1. Install Bitwarden Desktop (available in repos or as Flatpak)
2. Open Bitwarden Desktop
3. Go to **Settings** > **SSH Agent**
4. Enable **SSH Agent**
5. Add your SSH keys to Bitwarden vault (type: SSH Key)

The archway dotfiles already configure `SSH_AUTH_SOCK` to use Bitwarden's socket.

If you authenticated GitHub over HTTPS during install, switch to SSH after enabling the agent:

```bash
ssh -T git@github.com
gh config set git_protocol ssh
```

### 7.3 Configure Tailscale (Optional)

If you use Tailscale:

```bash
# Start and authenticate
sudo tailscale up

# Follow the URL to authenticate
```

### 7.3a NVIDIA GPU (if you have an NVIDIA card)

archway's base install is GPU-agnostic. The driver is best selected **in
archinstall**: for Turing (RTX 20) and newer, pick the **open kernel modules**
(`nvidia-open`) option. With current drivers that's usually all that's needed —
`nvidia-utils` blacklists nouveau, `nvidia_drm.modeset=1` is the default, and the
`-dkms` package rebuilds the initramfs on updates.

Verify after first boot:
```bash
nvidia-smi
```

If KDE Plasma-on-**Wayland** crashes (KWin `FormatInfo` crash loop), that's a
known driver/compositor version bug, **not** a config problem — use the
**Plasma (X11)** session (archway installs `plasma-x11-session`) or set
`KWIN_DRM_NO_AMS=1`. niri is unaffected. See
[docs/STABILITY.md](STABILITY.md#2-kwin-crashes-on-plasma-wayland-nvidia).
(Intel/AMD machines: skip this entirely.)

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

### 8.4 Recovery Model

archway does not configure filesystem snapshots by default. But most "broken"
states do **not** need a reinstall — see [docs/STABILITY.md](STABILITY.md) for
the full playbook. In short:

- **Boot drops to BIOS / Arch entry gone:** `just fix-boot` (works from the
  running system, or from the Arch ISO via `arch-chroot`). No reinstall.
- **KWin crashes back to the greeter on Plasma-Wayland (NVIDIA):** use the
  **Plasma (X11)** session, or set `KWIN_DRM_NO_AMS=1`. No reinstall.
- **niri/DMS broken:** log into KDE Plasma from the greeter.

If the OS is genuinely unrecoverable, the intended path is a fresh Arch install,
redeploying this repo, and restoring user data from backups.

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

> If Plasma *itself* crashes (KWin crash loop) on **Wayland** with an NVIDIA
> card, that's a known driver/compositor version bug — use the **Plasma (X11)**
> session or set `KWIN_DRM_NO_AMS=1`. See [docs/STABILITY.md](STABILITY.md#2-kwin-crashes-on-plasma-wayland-nvidia).
>
> Archway keeps `~/.config/environment.d/50-archway.conf` free of
> `QT_QPA_PLATFORM` / `SDL_VIDEODRIVER` etc. Those are set inside niri's
> `environment {}` block instead, so Plasma (X11) and Plasma Wayland remain
> usable fallbacks on both NVIDIA and non-NVIDIA machines after a full DMS install.

---

## Quick Reference

### Key Commands

| Task | Command |
|------|---------|
| Update system | `just update` or `sudo pacman -Syu && yay -Syu` |
| Sync archway | `just sync` |
| Validate system | `just doctor` or `./infra/doctor.sh` |
| Audit packages | `just audit` |

### Key Files

| File | Purpose |
|------|---------|
| `~/.zshrc` | Shell configuration (symlink to archway) |
| `~/.config/starship.toml` | Prompt configuration |
| `~/.config/environment.d/50-archway.conf` | Common session env (editor, XDG, SSH etc.; *no* compositor platform vars) |
| `~/.config/environment.d/90-dms.conf` | DMS environment (created by DMS) |
| `/etc/sddm.conf.d/autologin.conf` | SDDM autologin settings |

### Key Directories

| Directory | Purpose |
|-----------|---------|
| `~/archway` | This repository |
| `~/archway/infra/` | System scripts and package lists |
| `~/archway/dots/` | User dotfiles (source of symlinks) |
| `~/.config/` | User configuration (mostly symlinks) |

---

## Summary: Complete Installation Checklist

- Boot Arch ISO
- Run `archinstall` with settings from Part 1
- Reboot into new system
- Connect to network
- Clone archway repo
- Run `./infra/bootstrap.sh`
- Reboot
- Run `./infra/dotfiles.sh`
- Edit git config with your name/email
- Run `./install-dms.sh` (choose niri + your terminal)
- Reboot
- Run `./infra/doctor.sh` to validate
- Paste age private key from Bitwarden into `~/.config/sops/age/keys.txt`
- Re-run `just dotfiles` to decrypt secrets
- **If NVIDIA GPU: pick nvidia-open in archinstall; verify with `nvidia-smi`** (see §7.3a)
- Optional: Enroll fingerprints (see docs/STABILITY.md §5)
- Optional: Configure Bitwarden SSH agent
- Optional: Configure Tailscale
- Optional: Enable printing services
- Optional: Enable firewall
