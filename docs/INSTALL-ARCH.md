# Installing the Arch base

Run `archinstall` from the official Arch ISO and prefer its defaults.

Choose:

- UEFI;
- LUKS encryption;
- ext4 for the simplest recovery model;
- one of the graphical profiles described below;
- the installer-provided display manager;
- PipeWire;
- NetworkManager;
- the appropriate GPU driver offered by `archinstall`; and
- multilib if offered and Steam may be used later.

## Graphical profile

- **Niri + DankMaterialShell** is the required base for the full Archway
  install. Archinstall supplies Niri, DMS, the DMS greeter, the niri/DMS
  systemd binding, and `tuned-ppd`. Log into this session once before running
  Archway.
- **Niri** is supported only by `just install-minimal`. Archway leaves its
  conventional shell and display manager unchanged and does not add DMS.
- **KDE Plasma** is supported by `just install-minimal`. Archway leaves Plasma
  and its display manager unchanged and does not add Niri or DMS.

Keep the profile's default display manager. Niri + DankMaterialShell uses the
DMS greeter on greetd, conventional Niri defaults to LightDM, and Plasma uses
Plasma Login Manager. The full Archway installer checks the DMS greeter but
never rewrites or switches a display manager.

## Applications menu

Use these choices for all three profiles unless noted otherwise:

| Item | Recommended choice | Reason |
| --- | --- | --- |
| Audio | **PipeWire** | Archway requires `wpctl` and WirePlumber but does not install or repair the audio stack. |
| Bluetooth | **Enable** when the machine has or may use Bluetooth | Archway also installs and enables BlueZ, so the overlap is harmless and the base works before Archway runs. |
| Firewall | **UFW** | Archway installs and enables UFW. Do not choose firewalld alongside it. |
| Print service | **Enable** when printing may be needed | Archinstall enables CUPS; Archway supplies CUPS utilities and discovery packages but does not manage the service. |
| Power management | **TuneD** | This is compatible with every supported profile and gives desktop shells the PPD API through `tuned-ppd`. |

For **Niri + DankMaterialShell**, never select **power-profiles-daemon**: that
profile already includes the conflicting `tuned-ppd` package. Selecting TuneD
is safe (the packages are deduplicated) and ensures `tuned.service` is enabled.
For conventional Niri or Plasma, `power-profiles-daemon` is also compatible,
but TuneD works consistently across all supported profiles. Archway installs
neither daemon.

NetworkManager is selected in the separate network-configuration menu rather
than the Applications menu. Prefer **Use Network Manager (default backend)**,
or its iwd-backend variant when there is a specific reason to use iwd. Do not
choose **Copy ISO network configuration**: that copies standalone iwd and
systemd-networkd into the target instead. Archway requires active
NetworkManager and will not install it, enable it, or migrate another network
stack. No other additional packages are required; the pasteable installer
installs Git when necessary.

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

- On Niri+DMS, the full installer checks the active user services and DMS
  greeter, applies Archway's settings, and completes in one pass.
  It does not run `dms setup` or install DMS packages.
- On conventional Niri or KDE, use the minimal installer. It applies core,
  dotfiles, and secrets without touching the graphical profile.
- Archway does not provide a DMS conversion command. Use upstream DMS tooling
  directly if changing an existing graphical base later.

Then follow the fresh-install command in the repository README.

For boot recovery on the supported systemd-boot layout, see
[STABILITY.md](STABILITY.md). Run the recovery tool only when repairing a
supported systemd-boot installation.
