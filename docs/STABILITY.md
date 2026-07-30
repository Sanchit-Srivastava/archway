# Recovery notes

Start from the ownership boundary: Archway does not own boot, GPU drivers,
filesystems, mirrors, or the KDE baseline.

## DMS or niri fails

Select KDE Plasma in the display manager, then inspect:

```bash
dms doctor
journalctl --user -u dms -n 100
dms restart
just dms-config
```

KDE is the supported fallback; a DMS failure is not an OS failure.

## Optional packages fail

Core remains usable. Retry only the failed capability:

```bash
just extras
just dms
just tex
just zotero
```

## Secrets are unavailable

```bash
just secrets
```

The command validates the age key before changing the installed key or
decrypting targets.

## Arch/systemd-boot entry disappears

`infra/fix-boot.sh` is retained only for an Arch installation using
systemd-boot. It is not part of normal installation and must not be used on a
different bootloader:

```bash
just fix-boot
```

For CachyOS or another bootloader, use the distro's current recovery
documentation.
