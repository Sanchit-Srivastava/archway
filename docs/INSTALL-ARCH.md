# Installing the Arch base

Run `archinstall` from the official Arch ISO and prefer its defaults.

Choose:

- UEFI;
- LUKS encryption;
- ext4 for the simplest recovery model;
- the Niri profile for a minimal system, or KDE Plasma for a fuller base;
- the installer-provided display manager;
- PipeWire;
- NetworkManager;
- the appropriate GPU driver offered by `archinstall`; and
- multilib if offered and Steam may be used later.

For a Niri base, the DMS greeter is the preferred Wayland-native choice when it
is offered by the installed `archinstall` version. It uses greetd underneath
and can launch both Niri and a Plasma Wayland session installed later. LightDM
is the conservative fallback if DMS greeter is unavailable. For a KDE base,
the Plasma Login Manager default is appropriate. Archway keeps whichever
display manager the base profile configured and never switches it.

For a normal single-disk UEFI installation, prefer archinstall's default
systemd-boot with unified kernel images. It is supplied by systemd and has a
small maintenance surface. Use GRUB instead when legacy BIOS, unusual disk
layouts, or another explicit compatibility requirement calls for it. Archway
does not install, replace, or reconfigure either bootloader.

Archway does not install or repair these components. Confirm that the selected
graphical profile boots, networking and audio work, and the GPU driver is
functional before running Archway.

## Profile behavior

- A Niri base remains usable without DMS through archinstall's conventional
  Niri components. Running `just dms` replaces the session shell behavior with
  DMS but does not replace the display manager.
- A KDE base remains a normal Plasma installation. Running `just dms` adds a
  selectable Niri+DMS session.
- Installing Plasma later adds another Wayland session. Do not enable a second
  display manager; the existing one should launch both sessions.

Then follow the fresh-install command in the repository README.

For boot recovery on the supported systemd-boot layout, see
[STABILITY.md](STABILITY.md). The recovery tool is deliberately separate from
normal installation.
