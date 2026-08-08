# archway

Personal configuration-as-code for a familiar Arch Linux, CachyOS, or macOS
environment. The operating-system installer owns boot, filesystems, the base
desktop profile and display manager, GPU drivers, networking, audio,
repositories, and mirrors. Archway adds personal packages, dotfiles, secrets,
and optional DMS/niri configuration.

This is a public but heavily personal repository. It is intended to be cloned
and run by its owner, not used as a general-purpose distribution installer.

## Fresh Linux installation

First install one of:

- Arch Linux with `archinstall` and the Niri + DankMaterialShell, conventional
  Niri, or KDE Plasma profile; or
- CachyOS with KDE Plasma and its suggested defaults.

For the lightest Arch installation that will use DMS, prefer the Niri +
DankMaterialShell profile. Select NetworkManager, PipeWire, and TuneD; do not
combine that profile with the power-profiles-daemon application because the
profile already installs `tuned-ppd`. Keep the display manager selected by the
OS installer; Archway does not replace it. See the profile-specific
[archinstall choices](docs/INSTALL-ARCH.md) before installing.

NetworkManager is a required base-install choice. Do not select "Copy ISO
network configuration": that preserves standalone iwd/systemd-networkd rather
than installing NetworkManager. Archway checks this baseline but does not
replace or migrate the selected network stack.

Boot into the installed graphical profile, open a terminal, and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh)
```

For a recovery install that skips DMS and optional applications:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) safe
```

For reproducibility, replace `main` with a known-good release tag or pass a
specific ref:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh) --ref vYYYY.MM.DD
```

The normal installer:

1. installs the reliable native core;
2. applies ordinary dotfiles;
3. installs Bitwarden and prompts for the SOPS age key without echoing it;
4. decrypts secrets when a valid key is provided;
5. installs optional applications and the DMS/niri desktop independently;
6. runs upstream's `dms setup` and binds DMS to niri's systemd session; and
7. offers to reboot.

After reboot, select **niri**, log in once, then run:

```bash
cd ~/archway
just finish
```

`just finish` reapplies secrets, merges portable preferences into DMS's
current generated settings, installs plugins, and restarts DMS. It is safe to
rerun.

## Commands

### Installation

```bash
just install       # normal first stage
just install-safe  # core only; skip DMS and optional applications
just finish        # finish DMS/secrets after first niri login
just core          # install/reapply reliable native packages and services
just extras        # install/retry optional applications
just dms           # install/retry DMS and run `dms setup`
just dms-config    # reapply portable DMS/niri preferences
just secrets       # securely onboard/validate the age key and decrypt secrets
just dotfiles      # reapply ordinary dotfiles
```

Core failure stops installation. Extras and DMS failure leave the original base
desktop and the Archway core usable; retry them later with `just extras` or
`just dms`.

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
just zotero        # install Zotero separately through the AUR
```

These are deliberately excluded from the normal install because they can take
a long time and are not required for an immediately usable machine.

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
