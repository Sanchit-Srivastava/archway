# Installing the CachyOS base

Use the CachyOS graphical installer and prefer its suggested defaults.

Choose:

- KDE Plasma as the single desktop environment;
- encryption;
- either the suggested Btrfs layout for snapshots, compression, reflinks, and
  checksummed file data, or ext4 for the simplest operational/recovery model;
- the installer-selected bootloader and kernel; and
- the appropriate GPU driver offered by CachyOS.

CachyOS manages repositories, mirrors, optimized packages, snapshots, hardware
detection, and gaming setup. Archway leaves them unchanged.

For a machine with repeated unexplained Btrfs read-only events, ext4 is a
reasonable conservative choice after backing up and reinstalling. It should not
replace investigation of RAM, PCIe/power, firmware, kernel, or storage errors.
See [STABILITY.md](STABILITY.md) for filesystem guidance and Btrfs diagnostics.

Confirm that KDE boots and the hardware works, then run the minimal installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) minimal
```

This installs core, dotfiles, and secrets without installing or configuring
Niri, DMS, or another display manager.

To add a separate Niri+DMS work session later, use the upstream DMS installer.
Choose Niri, systemd integration, and Ghostty, but leave the optional DMS
greeter disabled so CachyOS retains Plasma Login Manager. Log out, select Niri,
log in once, and then run `just dms-config` to apply Archway's Niri/DMS
preferences. Bar layout, terminal defaults, and fingerprint authentication
remain the documented manual steps in [DMS.md](DMS.md).

For gaming, use CachyOS Hello or the current CachyOS documentation.
