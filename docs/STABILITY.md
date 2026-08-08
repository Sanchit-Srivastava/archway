# Stability and recovery

Start from the ownership boundary: Archway does not own boot, GPU drivers,
filesystems, mirrors, or the base graphical profile.

## Filesystem choice

Use **ext4** when the priority is the smallest operational surface and familiar
offline recovery. Use **Btrfs** when snapshots, transparent compression,
reflinks, checksummed file data, and subvolumes are worth the additional space
accounting and recovery knowledge.

For this repository, either is supported because Archway does not create or
modify filesystems. A repeated Btrfs failure on one machine is not by itself
proof that Btrfs is the cause. Btrfs deliberately switches to read-only when an
internal consistency check fails; the initiating fault may instead be storage,
RAM, PCIe/power, firmware, a kernel bug, or exhaustion of allocatable metadata.
Ext4 can make recovery simpler, but it does not fix any of those underlying
faults and does not checksum ordinary file data.

If installing CachyOS with Btrfs:

- keep the installer's default subvolume and compression layout;
- keep real backups outside the Btrfs device;
- retain substantial free space and inspect `btrfs filesystem usage -T /`,
  not only `df`;
- run and review periodic scrub results;
- keep VM/container images and other high-churn data out of root snapshots;
- do not run balances on a schedule without an allocation-based reason; and
- do not broadly disable copy-on-write. NOCOW also disables data checksums and
  compression for affected files.

Large mutable VM disk images and container layers can fragment under
copy-on-write, and root snapshots can retain their old extents. If this workload
is important, use a dedicated subvolume excluded from root snapshots. Set any
NOCOW attribute only on an empty directory before files are created, after
accepting the checksum/compression tradeoff.

## Before deployment

Run the read-only preflight:

```bash
cd ~/archway
sudo just health
```

`just core` also refuses to proceed when `/` is not mounted read-write or when
Btrfs has non-zero persistent device error counters. The health command does
not remount, scrub, balance, repair, or reset counters.

## If Btrfs becomes read-only

Stop write-heavy workloads and capture the first error before rebooting:

```bash
findmnt -no SOURCE,FSTYPE,OPTIONS /
sudo journalctl -k -b --no-pager |
  grep -Ei 'BTRFS|I/O error|nvme|AER|corrupt|readonly|read-only|reset|timeout'
sudo btrfs device stats /
sudo btrfs filesystem usage -T /
sudo btrfs scrub status /
```

After reboot, also inspect the previous boot:

```bash
sudo journalctl -k -b -1 --no-pager |
  grep -Ei 'BTRFS|I/O error|nvme|AER|corrupt|readonly|read-only|reset|timeout'
```

Do not repeatedly remount the filesystem read-write, and do not run
`btrfs check --repair` from a normal troubleshooting recipe. Back up readable
data first. An offline `btrfs check --readonly` or rescue mount may help with
diagnosis, but the exact action depends on the first kernel error.

NVMe health alone is not conclusive. Also check the NVMe error log and
temperature, system firmware, PCIe/AER messages, power loss history, and RAM.
For recurring failures under gaming/VM load, test without memory overclocking,
XMP/EXPO, CPU/GPU undervolting, or PCIe power-saving changes and compare against
an LTS or distribution-default kernel.

## Archway risk surface

Archway's changes fall into four different risk levels:

1. Package upgrades and installs are the largest system-wide mutation. Core
   performs a full rolling-release upgrade, then installs a broad personal
   package set. A conflict now stops instead of silently authorizing removal of
   a distro package.
2. Enabled system services (`ufw`, `tailscaled`, `keyd`, Avahi, and Bluetooth)
   are global behavior changes. They do not explain Btrfs corruption, but can
   affect networking, container ingress, input, discovery, and boot diagnostics.
3. DMS/niri, AUR packages, Oh My Zsh plugins, and DMS plugins are moving
   third-party components. The OS-provided desktop remains the recovery
   session, and optional failures must not invalidate core.
4. Ordinary application dotfiles are user-scoped. They can break one program
   but should not make the root filesystem read-only. Existing files are moved
   to unique `*.pre-archway.bak*` paths rather than overwritten.

Archway uses KWallet as its Secret Service provider for both Niri and Plasma. A
previous version globally masked it and installed GNOME Keyring; re-running
`just dotfiles` removes only the retired Archway-owned mask. Do not enable a
second Secret Service provider beside KWallet.

## DMS or niri fails

Select the original base session in the display manager, then inspect:

```bash
dms doctor
journalctl --user -u dms -n 100
dms restart
just dms-config
```

The base profile is the supported fallback; a DMS failure is not an OS failure.

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
