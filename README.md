# archway

Personal configuration-as-code for a familiar Arch Linux, CachyOS, or macOS
environment. The operating-system installer owns boot, filesystems, KDE, GPU
drivers, networking, audio, repositories, and mirrors. Archway adds personal
packages, dotfiles, secrets, and optional DMS/niri configuration.

This is a public but heavily personal repository. It is intended to be cloned
and run by its owner, not used as a general-purpose distribution installer.

## Fresh Linux installation

First install either:

- Arch Linux with `archinstall` and the KDE Plasma profile; or
- CachyOS with KDE Plasma and its suggested defaults.

Boot into KDE, open a terminal, and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Sanchit-Srivastava/archway/main/remote-install.sh)
```

For a recovery install that skips DMS and all AUR extras:

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
5. installs optional extras and DMS/niri from native packages;
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
just install-safe  # core only; skip DMS and AUR extras
just finish        # finish DMS/secrets after first niri login
just core          # install/reapply reliable native packages and services
just extras        # install/retry optional native and AUR extras
just dms           # install/retry DMS and run `dms setup`
just dms-config    # reapply portable DMS/niri preferences
just secrets       # securely onboard/validate the age key and decrypt secrets
just dotfiles      # reapply ordinary dotfiles
```

Core failure stops installation. Extras and DMS failure leave KDE and the
Archway core usable; retry them later with `just extras` or `just dms`.

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
just secrets-edit vdirsyncer.env
just secrets-show vdirsyncer.env
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
- [Secrets and age-key handling](docs/SECRETS.md)
- [Recovery notes](docs/STABILITY.md)
