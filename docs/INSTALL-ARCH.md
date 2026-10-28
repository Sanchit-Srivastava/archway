# Installing the Arch base

Boot the official Arch ISO in **UEFI mode**, run `archinstall`, and prefer its
defaults except for the explicit choices below. Check `archinstall --version`:
the profile guidance here was checked against **4.5** on **2026-10-27**.

Choose:

- LUKS encryption;
- ext4 for the simplest recovery model;
- **KDE Plasma**, with the recommended **plasma-meta** flavor;
- **Plasma Login Manager** (Plasma's default greeter in archinstall 4.5);
- PipeWire;
- NetworkManager;
- the appropriate GPU driver offered by `archinstall`; and
- multilib if offered and Steam may be used later.

## Graphical profile

- **KDE Plasma + Plasma Login Manager is the default.** Establish password
  login, logout, and reboot first. Then add Niri+DMS through the Dux Installer
  with its optional greeter disabled, retaining Plasma as a recovery session.
  Follow [Reliable graphical login](LOGIN.md), then run the full Archway
  install from Niri+DMS. Use `just install-minimal` if staying with Plasma alone.
- **Niri** is an alternative for a deliberately smaller base without Plasma
  recovery. Establish a working session and login manager, then use the separate
  [Dux Installer](DMS.md#upstream-installation-and-upgrades) to configure DMS.
  Until DMS is set up, only `just install-minimal` applies.
- **niri - DankMaterialShell** is still the label of archinstall 4.5's combined
  profile. It requests the removed `dms-shell-niri` package and selects an
  obsolete bundled greeter command. Do not use it for a fresh install until
  those references are fixed in a released archinstall version. Existing
  working installations do not need to be reinstalled.

The current Arch package is `dux-shell`, providing `dms-shell` and replacing
the old split packages. A `replaces` entry does not provide the missing
`dms-shell-niri` package name for a fresh install. This is a source/package
metadata mismatch, not a claim that an end-to-end installation was tested.

Keep an existing working display manager. Conventional Niri defaults to
LightDM, and Plasma uses Plasma Login Manager. Plasma Login Manager and SDDM
can also launch Niri, so adding Plasma or changing the login screen does not
require reinstalling Niri+DMS.

Archinstall 4.5's DMS greeter integration still points at a wrapper that
current `dux-shell` packages do not ship. If choosing Dux Greeter,
install and configure its separate upstream package before relying on it for
login. Otherwise keep Plasma Login Manager or SDDM if already configured.
See [DMS login-manager setup and recovery](DMS.md#login-manager).

The full Archway installer checks the selected display manager's unit file
and service state, but never installs, rewrites, or switches a display manager.

The Dux docs also suggest archinstall's **minimal** OS profile. That is a valid
upstream starting point, but it is not the same as Archway's
`just install-minimal`: a minimal OS still needs working audio, networking,
power management, and a selected login manager before a full Archway install.
The graphical-base route above keeps those responsibilities explicit.

After adding DMS, log out and select the installed **Niri** session (which
launches `niri-session`), then check:

```bash
systemctl --user status niri.service dms.service
```

Do not start a nested `niri` inside Plasma as a substitute.

## Applications menu

Use these choices for the default Plasma base or the conventional Niri alternative:

| Item | Recommended choice | Reason |
| --- | --- | --- |
| Audio | **PipeWire** | Archway requires `wpctl` and WirePlumber but does not install or repair the audio stack. |
| Bluetooth | **Enable** when the machine has or may use Bluetooth | Archway also installs and enables BlueZ, so the overlap is harmless and the base works before Archway runs. |
| Firewall | **UFW** | Archway installs and enables UFW. Do not choose firewalld alongside it. |
| Print service | **Enable** when printing may be needed | Archinstall enables CUPS; Archway supplies CUPS utilities and discovery packages but does not manage the service. |
| Power management | **TuneD** | This is compatible with every supported profile and gives desktop shells the PPD API through `tuned-ppd`. |

Selecting **TuneD** explicitly installs `tuned` and `tuned-ppd` and enables
`tuned.service`. **power-profiles-daemon** is also a valid alternative; choose
one implementation, never both. Archinstall 4.5 no longer bundles `tuned-ppd`
in its Niri+DMS profile, unlike 4.4. An older installation may already have
it, so check before switching power-management implementations. Archway
installs neither daemon.

NetworkManager is selected in the separate network-configuration menu rather
than the Applications menu. Prefer **Use Network Manager (default backend)**,
or its iwd-backend variant when there is a specific reason to use iwd. Do not
choose **Copy ISO network configuration** or **Use standalone iwd**: these
use the ISO's networking or standalone iwd/networkd/resolved instead of setting
up NetworkManager. Archway requires active
NetworkManager and will not install it, enable it, or migrate another network
stack. The pasteable installer installs Git when necessary.

For X11 applications under Niri, add **`xwayland-satellite`** through the base
installer or let the Dux Installer supply it. Archinstall's Niri profiles
include `xorg-xwayland`, but that alone is not Niri's X11 bridge. Current Niri
starts satellite automatically; do not add a second startup command or a
hard-coded `DISPLAY`. Keep `xdg-desktop-portal-gnome` for Niri screen sharing
and a working PolicyKit authentication agent in the base session.

## Secret-service provider

Installing Bitwarden may ask for a provider of `org.freedesktop.secrets`. This
is the desktop Secret Service used by applications to store local credentials;
it is not a choice of browser password manager and does not replace the
Bitwarden vault.

Choose **KWallet** for Archway. It implements the standard Secret Service API
under Niri and is also Plasma's native credential store, so it avoids adding a
second provider when Plasma is installed. Archway lists KWallet explicitly to
make Bitwarden's dependency deterministic.

GNOME Keyring is a reasonable alternative for a GNOME-oriented system, but is
not preferred for this Niri/Plasma combination. Choose KeePassXC only when a
KeePassXC database will be the machine's active Secret Service; its
integration must be enabled and the database must be open and unlocked. Avoid
running multiple providers because only one process can own the Secret Service
D-Bus name.

KWallet can ask for a wallet password in a Niri/DMS session. Automatic unlock
requires `kwallet-pam` and matching login-manager PAM integration; Archway does
not rewrite PAM. Plasma's normal login path provides the most seamless KWallet
integration.

For a normal single-disk UEFI installation, prefer archinstall's default
systemd-boot with unified kernel images. It is supplied by systemd and has a
small maintenance surface. Use GRUB instead when legacy BIOS, unusual disk
layouts, or another explicit compatibility requirement calls for it. Archway
does not install, replace, or reconfigure either bootloader.

Archway does not install or repair the graphical profile, networking, audio
stack, GPU driver, or bootloader. Confirm that those components work before
running Archway. For a full installation, log into Niri+DMS and launch Archway
from that active session.

## Profile behavior

- On Niri+DMS, the full installer checks the active user services and selected
  display manager, applies Archway's settings, and completes in one pass.
  It does not run `duxinstall`, `dms setup`, or install DMS packages.
- On conventional Niri or KDE, use the minimal installer. It applies core,
  dotfiles, and secrets without touching the graphical profile.
- Archway does not provide a DMS conversion command. Use upstream DMS tooling
  directly if changing an existing graphical base later.

Then follow the fresh-install command in the repository README.

For boot recovery on the supported systemd-boot layout, see
[STABILITY.md](STABILITY.md). Run the recovery tool only when repairing a
supported systemd-boot installation.

## Upstream references

- [Archinstall 4.5 Niri+DMS profile](https://github.com/archlinux/archinstall/blob/4.5/archinstall/default_profiles/desktops/niri_dms.py)
- [Archinstall 4.5 Plasma profile and login-manager default](https://github.com/archlinux/archinstall/blob/4.5/archinstall/default_profiles/desktops/plasma.py)
- [Archinstall 4.5 greeter setup](https://github.com/archlinux/archinstall/blob/4.5/archinstall/lib/profile/profiles_handler.py)
- [Current Arch Dux package](https://archlinux.org/packages/extra/x86_64/dux-shell/)
- [Archinstall power-management choices](https://github.com/archlinux/archinstall/blob/4.5/archinstall/applications/power_management.py)
- [Archinstall network choices](https://github.com/archlinux/archinstall/blob/4.5/archinstall/lib/models/network.py)
- [Archinstall bootloader defaults](https://github.com/archlinux/archinstall/blob/4.5/archinstall/lib/models/bootloader.py)
- [Niri Xwayland integration](https://niri-wm.github.io/niri/Xwayland.html)

Package metadata is newer than some upstream quick-start examples. In
particular, do not copy an old `pacman -S dms-shell-niri` command from a guide.
