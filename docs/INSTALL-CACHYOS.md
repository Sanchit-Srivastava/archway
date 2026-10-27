# Installing the CachyOS base

Use the CachyOS graphical installer and prefer its suggested defaults.

Choose:

- KDE Plasma as the single desktop environment;
- encryption;
- either the suggested Btrfs layout for snapshots, compression, reflinks, and
  checksummed file data, or ext4 for the simplest operational/recovery model;
- the installer-selected bootloader and kernel; and
- the appropriate GPU driver offered by CachyOS.

Prefer Plasma Login Manager when offered for a fresh Plasma installation.
Keep a working SDDM if that is what the installer supplies; do not replace it
merely to match this recommendation. DMS Greeter is not the default.

CachyOS manages repositories, mirrors, optimized packages, snapshots, hardware
detection, and gaming setup. Archway leaves them unchanged.

For a machine with repeated unexplained Btrfs read-only events, ext4 is a
reasonable conservative choice after backing up and reinstalling. It should not
replace investigation of RAM, PCIe/power, firmware, kernel, or storage errors.
See [STABILITY.md](STABILITY.md) for filesystem guidance and Btrfs diagnostics.

First verify password login, logout/login, and reboot into Plasma using
[Reliable graphical login](LOGIN.md). If staying with Plasma, run the minimal
installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) minimal
```

This installs core, dotfiles, and secrets without installing or configuring
Niri, DMS, or another display manager.

To add a separate Niri+DMS work session later, use the
[Dux Installer](DMS.md#upstream-installation-and-upgrades) (`duxinstall`).
Choose Niri, systemd integration, and Ghostty, but leave the optional DMS
greeter disabled so CachyOS retains its existing working login manager. Do not
select `--all-features`, which includes the greeter. Log out, select Niri,
log in, and complete the staged checks in [LOGIN.md](LOGIN.md). On a fresh
system, run the full installer from Niri+DMS. If Archway was already installed,
`just dms-config` reapplies its Niri/DMS preferences without another full install.
Bar layout, terminal defaults, and fingerprint authentication
remain the documented manual steps in [DMS.md](DMS.md).

For gaming, use CachyOS Hello or the current CachyOS documentation.
