# Installing the Arch base

Run `archinstall` from the official Arch ISO and prefer its defaults.

Choose:

- UEFI;
- LUKS encryption;
- ext4 for the simplest recovery model;
- the KDE Plasma desktop profile;
- the installer-provided display manager;
- PipeWire;
- NetworkManager;
- the appropriate GPU driver offered by `archinstall`; and
- multilib if offered and Steam may be used later.

Archway does not install or repair these components. Confirm that KDE boots,
networking works, and the GPU driver is functional before running Archway.

Then follow the fresh-install command in the repository README.

For boot recovery on the supported systemd-boot layout, see
[STABILITY.md](STABILITY.md). The recovery tool is deliberately separate from
normal installation.

