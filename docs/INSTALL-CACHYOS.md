# Installing the CachyOS base

Use the CachyOS graphical installer and prefer its suggested defaults.

Choose:

- KDE Plasma as the single desktop environment;
- encryption;
- either the suggested Btrfs layout for snapshots, compression, reflinks, and
  checksummed file data, or ext4 for the simplest operational/recovery model;
- the installer-selected bootloader and kernel; and
- the appropriate GPU driver offered by CachyOS.

CachyOS owns repositories, mirrors, optimized packages, snapshots, hardware
detection, and gaming setup. Archway does not alter any of them.

For a machine with repeated unexplained Btrfs read-only events, ext4 is a
reasonable conservative choice after backing up and reinstalling. It should not
replace investigation of RAM, PCIe/power, firmware, kernel, or storage errors.
See [STABILITY.md](STABILITY.md) for the decision tradeoff and Btrfs diagnostics.

Confirm that KDE boots and the hardware works before running the pasteable
Archway command from the README.

For gaming, use CachyOS Hello or the current CachyOS documentation. There is no
Archway gaming recipe.
