# archway

Archway is my personal configuration-as-code repository for Arch Linux,
CachyOS, and macOS. It installs packages, dotfiles, secrets, and selected
Niri+DMS settings on top of an already working system. The OS installer still
handles boot, filesystems, hardware drivers, networking, audio, repositories,
mirrors, and the base desktop.

The repository is public, but it reflects my own machines and preferences. It
is not a general-purpose Linux installer.

## Fresh Linux installation

The usual Arch setup starts with `archinstall`'s **Niri + DankMaterialShell**
profile. Select NetworkManager, PipeWire, and TuneD, and keep the DMS greeter
provided by the profile. Do not add `power-profiles-daemon`; the profile already
includes the conflicting `tuned-ppd` package. Archway checks that this desktop
is working but leaves its installation and repair to `archinstall`.

For Arch or CachyOS with KDE Plasma, use the minimal installer. It installs the
required packages, dotfiles, and secrets without changing the desktop or
display manager. See the profile-specific
[Arch installation guide](docs/INSTALL-ARCH.md) before installing Arch.

NetworkManager must be selected during OS installation. Do not choose "Copy
ISO network configuration," which copies standalone iwd and systemd-networkd
instead. Archway checks that NetworkManager is running but does not replace or
migrate another network setup.

Boot into the installed graphical profile, open a terminal, and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh)
```

For KDE or another existing desktop:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) minimal
```

For reproducibility, replace `main` with a known-good release tag or pass a
specific ref:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) --ref vYYYY.MM.DD
```

Run the full installer after logging into the working Niri+DMS session. It:

1. installs the required native packages;
2. applies dotfiles;
3. installs Bitwarden and prompts for the SOPS age key without echoing it;
4. decrypts secrets when a valid key is provided;
5. installs optional applications;
6. checks Niri, DMS, and the greetd configuration after package updates; and
7. applies selected preferences, installs and enables DMS plugins, and
   restarts DMS.

The installation completes in one pass. There is no intermediate reboot or
mandatory finish command.

## Commands

### Installation

```bash
just install          # configure an existing archinstall Niri+DMS session
just install-minimal  # core, dotfiles, and secrets; leave the desktop alone
just core          # install/reapply required native packages and services
just extras        # install/retry optional applications
just dms-config    # reapply selected DMS/niri preferences
just secrets       # set up/validate the age key and decrypt secrets
just dotfiles      # reapply dotfiles
```

A core failure stops the installation. If an optional application fails, the
desktop and core packages remain usable; retry it later with `just extras`. To
add DMS to another desktop, use the upstream DMS installer.

### Default applications

Archway installs and selects a small cross-session set of defaults:

- imv for common image formats;
- mpv for audio and video;
- Kate for plain and structured text;
- Okular for PDFs, EPUB, DjVu, and comic archives; and
- Ark for ordinary archives.

Zathura remains installed for explicit LaTeX/PDF workflows. The defaults are
stored in `dots/mimeapps.list` and apply in both Niri and Plasma sessions.
Office-suite formats have no default because Archway does not install a full
office suite.

### Slow optional applications

```bash
just tex           # install the large TeX Live toolchain
```

TeX has a separate command because it takes a long time to install and is not
needed for the initial setup. Install applications such as Zotero through your
usual package-management workflow.

### Maintenance

```bash
just sync          # fast-forward pull and reapply config without a system upgrade
just update        # update native packages, then AUR packages if yay exists
sudo just health   # check filesystem state and recent kernel errors
just pull-dots     # import selected live niri files; never import DMS runtime JSON
just fix-boot      # Arch/systemd-boot recovery only; not part of installation
```

### Secrets

```bash
just secrets-edit ssh_config.local
just secrets-show ssh_config.local
```

Private values are SOPS-encrypted before being committed. The age private key
must never enter this repository. See [docs/SECRETS.md](docs/SECRETS.md).

### Development

These are safe on a development machine:

```bash
just lint
just check-fmt
just fmt           # writes formatting changes
```

Never run installation, bootstrap, or recovery infrastructure on a
development machine. Target scripts assume a real Arch-family system.

### macOS

```bash
just bootstrap-mac
just setup-mac
just dotfiles
```

Only the package-backed user environment is shared with macOS. Linux desktop
and system configuration remain Linux-only.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Arch installation choices](docs/INSTALL-ARCH.md)
- [CachyOS installation choices](docs/INSTALL-CACHYOS.md)
- [DMS and niri](docs/DMS.md)
- [Research workflow](docs/RESEARCH-WORKFLOW.md)
- [Notes-system design proposal](docs/NOTES-DESIGN.md)
- [Secrets and age-key handling](docs/SECRETS.md)
- [Recovery notes](docs/STABILITY.md)
