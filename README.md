# archway

Personal configuration-as-code for a familiar Arch Linux, CachyOS, or macOS
environment. The operating-system installer owns boot, filesystems, the base
desktop profile and display manager, GPU drivers, networking, audio,
repositories, and mirrors. Archway adds personal packages, dotfiles, secrets,
and portable configuration for an existing Niri+DMS desktop.

This is a public but heavily personal repository. It is intended to be cloned
and run by its owner, not used as a general-purpose distribution installer.

## Fresh Linux installation

The normal installation contract is Arch Linux installed with `archinstall`'s
**Niri + DankMaterialShell** profile. Select NetworkManager, PipeWire, and
TuneD; do not combine that profile with `power-profiles-daemon` because it
already installs `tuned-ppd`. Keep the profile's DMS greeter. Archway validates
the graphical baseline but does not install, replace, or repair it.

Arch or CachyOS with KDE Plasma is supported by the separate minimal install.
That path installs the Archway core, dotfiles, and secrets while leaving the
desktop and display manager untouched. See the profile-specific
[archinstall choices](docs/INSTALL-ARCH.md) before installing Arch.

NetworkManager is a required base-install choice. Do not select "Copy ISO
network configuration": that preserves standalone iwd/systemd-networkd rather
than installing NetworkManager. Archway checks this baseline but does not
replace or migrate the selected network stack.

Boot into the installed graphical profile, open a terminal, and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh)
```

For KDE or another base that should remain graphically untouched:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) minimal
```

For reproducibility, replace `main` with a known-good release tag or pass a
specific ref:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) --ref vYYYY.MM.DD
```

Run the normal installer only after logging into the working archinstall
Niri+DMS session. It:

1. installs the reliable native core;
2. applies ordinary dotfiles;
3. installs Bitwarden and prompts for the SOPS age key without echoing it;
4. decrypts secrets when a valid key is provided;
5. installs optional applications;
6. verifies that package updates did not break the OS-provided Niri, DMS, or
   greetd baseline; and
7. merges portable preferences, installs and enables selected DMS plugins, and
   restarts DMS.

The installation completes in one pass. There is no intermediate reboot or
mandatory finish command.

## Commands

### Installation

```bash
just install          # configure an existing archinstall Niri+DMS base
just install-minimal  # core, dotfiles, and secrets; leave the desktop alone
just core          # install/reapply reliable native packages and services
just extras        # install/retry optional applications
just dms-config    # reapply portable DMS/niri preferences
just secrets       # securely onboard/validate the age key and decrypt secrets
just dotfiles      # reapply ordinary dotfiles
```

Core failure stops installation. Extras failure leaves the OS-provided desktop
and the Archway core usable; retry it later with `just extras`. Archway does not
provide a command for adding DMS to another profile; use DMS's own installer if
that is ever desired.

### Default applications

Archway installs and selects a small cross-session set of defaults:

- imv for common image formats;
- mpv for audio and video;
- Kate for plain and structured text;
- Okular for PDFs, EPUB, DjVu, and comic archives; and
- Ark for ordinary archives.

Zathura remains installed for explicit LaTeX/PDF workflows. The defaults are
stored in `dots/mimeapps.list` and apply in both Niri and Plasma sessions.
Office-suite formats are deliberately not assigned because Archway does not
currently install a full office suite.

### Slow optional applications

```bash
just tex           # install the large TeX Live toolchain
```

TeX is deliberately excluded from the normal install because it can take a
long time and is not required for an immediately usable machine. Install
optional applications such as Zotero through your usual package-management
workflow.

### Maintenance

```bash
just sync          # fast-forward pull and reapply config without a system upgrade
just update        # update native packages, then AUR packages if yay exists
sudo just health   # read-only filesystem/kernel-error deployment preflight
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

- [Architecture and ownership](docs/ARCHITECTURE.md)
- [Arch installation choices](docs/INSTALL-ARCH.md)
- [CachyOS installation choices](docs/INSTALL-CACHYOS.md)
- [DMS/niri lifecycle](docs/DMS.md)
- [Research workflow](docs/RESEARCH-WORKFLOW.md)
- [Planned notes-system redesign](docs/NOTES-DESIGN.md)
- [Secrets and age-key handling](docs/SECRETS.md)
- [Recovery notes](docs/STABILITY.md)
