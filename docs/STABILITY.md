# Stability & Recovery

Troubleshooting and recovery reference for archway. The guiding principle:
**almost nothing here requires reinstalling the OS.** A vanished boot entry or a
graphics crash is a targeted fix, not a wipe.

Read the [TL;DR](#tldr-if-something-is-broken-right-now) first if a machine is
broken right now.

---

## TL;DR: if something is broken right now

| Symptom | Fix | Reinstall? |
| --- | --- | --- |
| Reboot drops straight to BIOS; Arch entry gone | [Boot entry vanished](#1-boot-entry-vanished-drops-to-bios) → `just fix-boot` (or from the Arch ISO) | **No** |
| KWin crashes back to SDDM when entering Plasma | [KWin/NVIDIA Wayland bug](#2-kwin-crashes-on-plasma-wayland-nvidia) → use Plasma **(X11)** session, or `KWIN_DRM_NO_AMS=1` | **No** |
| Boot "stuck" on a random line | Usually a GPU/driver stall → see [§2](#2-kwin-crashes-on-plasma-wayland-nvidia) | **No** |
| Discord keeps crashing in calls | [§2](#2-kwin-crashes-on-plasma-wayland-nvidia) + [Discord](#3-discord-crashes) | **No** |
| Red/orange text flashing at boot | [Capture the logs](#capturing-boot-logs), match against this doc | **No** |

---

## Health check

```bash
just doctor                 # runtime state, config drift, boot safety
just check boot-entry       # firmware entry + removable fallback present
just audit                  # package drift (installed vs repo lists)
```

doctor.sh deliberately checks **runtime state, config/symlink drift, and boot
safety** — not "is package X installed" (that's `just audit`). If a problem's
only fix is `pacman -S X`, the audit is the right tool.

---

## 1. Boot entry vanished (drops to BIOS)

**Symptom.** After a reboot the machine goes straight to the firmware/BIOS
screen; the "Linux Boot Manager" entry is gone. Seen on the ThinkPad.

**Cause.** The UEFI firmware's NVRAM boot variables were wiped or pruned (some
firmware does this after a firmware update, CMOS/battery event, or when it
decides an entry is "invalid"). The on-disk system is fine — the firmware just
forgot where the bootloader is.

**Why a reinstall is the wrong fix.** Reinstalling rewrites the bootloader as a
side effect. The actual fix is `bootctl install`, which rewrites systemd-boot to
the ESP, recreates the NVRAM entry, **and** writes the removable-media fallback
`EFI/BOOT/BOOTX64.EFI` (which firmware boots even if NVRAM is wiped again).

### Fix A — machine still boots

```bash
just fix-boot
```

### Fix B — machine won't boot (from the Arch ISO)

1. Boot the Arch install USB in **UEFI** mode.
2. `lsblk -f` to find your partitions.
3. Unlock + mount root and ESP (adjust device names):
   ```bash
   cryptsetup open /dev/nvme0n1p2 root
   mount /dev/mapper/root /mnt
   mount /dev/nvme0n1p1 /mnt/boot       # your vfat ESP
   ```
4. Enter and repair:
   ```bash
   arch-chroot /mnt
   cd /root/archway        # or ~/archway under your user
   ./infra/fix-boot.sh     # auto-skips sudo when run as root in the chroot
   ```
5. Leave and reboot:
   ```bash
   exit; umount -R /mnt; reboot
   ```

### Make it stick (ThinkPad/Lenovo)

In firmware setup: enable **OS Optimized Defaults**, ensure **Linux Boot
Manager** is enabled and first in the UEFI boot order, and disable any
aggressive "boot entry cleanup" option. The `EFI/BOOT/BOOTX64.EFI` fallback that
`fix-boot.sh` writes is the safety net if NVRAM is cleared again.

---

## 2. KWin crashes on Plasma-Wayland (NVIDIA)

**Symptom.** Selecting KDE Plasma at the greeter shows a KWin crash and bounces
back to the login screen after some black screens. The journal shows:

```
kwin_wayland: KWin::FormatInfo ... Assertion 'this->_M_is_engaged()' failed.
KCrash: Application 'kwin_wayland' crashing... crashRecursionCounter = 2
```

**Honest root cause.** This is a **version-compatibility bug** between recent
KWin and recent NVIDIA drivers (e.g. KWin 6.7 + nvidia-open 610 on multi-monitor
setups), not a misconfiguration on your machine. KWin's atomic mode-setting path
asks the NVIDIA DRM driver for a pixel-format descriptor it doesn't advertise,
dereferences an empty `std::optional`, and aborts in a loop. It clusters on
**multi-monitor NVIDIA Wayland** setups.

> Earlier versions of this doc blamed the `kms`/nouveau initramfs race. On the
> actual desktop, nouveau is already blacklisted by `nvidia-utils` and never
> loads — so that was **not** the cause, and a "remove the kms hook" script
> would not have fixed it. The real issue is the KWin↔driver version mismatch.

**This only affects the KDE/Plasma fallback. niri (the daily driver) is
unaffected** — which is why day-to-day use is fine.

### Fixes (simplest first)

**A — use the Plasma (X11) session.** archway installs `plasma-x11-session`, so
the greeter offers **"Plasma (X11)"**. X11 sidesteps the NVIDIA-Wayland bug
entirely. This is the most reliable fallback for presenting/eduroam — just pick
it at the greeter instead of "Plasma (Wayland)".

**B — disable KWin atomic mode-setting** (if you want Plasma on Wayland):
```bash
echo 'KWIN_DRM_NO_AMS=1' | sudo tee -a /etc/environment
```
Log out and back in. Reported to fix near-identical RTX 2060 + dual-monitor
setups. Slight smoothness cost.

**C — driver/KWin version.** The bug comes and goes with updates. If A/B don't
satisfy and you're on a brand-new driver branch, moving to a more-baked NVIDIA
driver (or waiting for the next KWin point release) is the last resort.

### Clearing a stuck GPU cache

If Plasma crashes persist after a driver/KWin update even on X11, clear the
per-user shader cache and retry:
```bash
rm -rf ~/.cache/kwin ~/.cache/plasma* ~/.cache/qtshadercache* ~/.cache/mesa_shader_cache*
```

---

## 3. Discord crashes

**Primary cause:** the NVIDIA Wayland instability in §2. The call crashes
(`coredumpctl list | grep -i discord` shows SIGSEGVs) typically stop once you're
on a stable GPU path (X11 Plasma, or niri which is unaffected).

**If they persist:** disable hardware acceleration in Discord (User Settings →
Advanced), or use **Vesktop** (`vesktop-bin` from the AUR) which has better
Wayland/screenshare support. Not installed by default — add per-machine if
wanted.

---

## 4. NVIDIA driver setup (fresh install)

archway's base install is GPU-agnostic — it does **not** install or configure
NVIDIA. On a machine with an NVIDIA card:

1. **Pick the NVIDIA driver in archinstall.** For Turing (RTX 20) and newer,
   choose the **open kernel modules** option (`nvidia-open`). That's the
   upstream-recommended, forward-compatible choice for your hardware.
2. That's usually enough. With current drivers:
   - `nvidia-utils` already ships the **nouveau blacklist**.
   - `nvidia_drm.modeset=1` is the **default** since driver 560.
   - The **`-dkms`** package ships a pacman hook that rebuilds the initramfs on
     updates.
3. If `nvidia-smi` works and Plasma-on-X11 / niri render correctly, you're done.

> archinstall installs the driver *packages* but does not add the nvidia modules
> to `mkinitcpio` or remove the `kms` hook (open issue archlinux/archinstall#1239).
> In practice this rarely matters now (blacklist + default modeset + dkms hook
> cover it). If you ever do hit a true nouveau-grabbing-the-GPU situation
> (nouveau actually loading at boot — check `lsmod | grep nouveau`), the manual
> fix is: add `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)` to
> `/etc/mkinitcpio.conf`, ensure nouveau is blacklisted, run `sudo mkinitcpio -P`,
> reboot. This is a rare one-time step, not something archway scripts.

The KWin-on-Wayland crash in §2 is a **separate, software** issue and is not
fixed by any of the above — use the X11 session for it.

---

## 5. Fingerprint, keyring, and portals (manual steps)

archway used to edit PAM files (`/etc/pam.d/...`) and write a system-wide portal
config automatically. Those in-place edits to auth files are fragile on a rolling
release (a `pambase` update can shift the format and **lock you out**), so they
are now one-time manual steps. Most are also already handled by KDE.

### Fingerprint (fprintd)

KDE Plasma already ships a ready PAM config for its lock screen
(`/etc/pam.d/kde-fingerprint`), so enrolling is often all you need:

```bash
sudo pacman -S --needed fprintd
fprintd-enroll          # follow the prompts
fprintd-verify          # test
```

To use fingerprint for `sudo` and console login, add (once) to the **top** of
the `auth` section in `/etc/pam.d/system-auth`:

```
auth      sufficient    pam_fprintd.so
```

> Edit carefully and keep a root shell open while testing — a malformed
> `system-auth` can block logins. The line order matters: `pam_fprintd.so` as
> `sufficient` before `pam_unix.so` lets fingerprint succeed but still falls
> back to password.

### gnome-keyring auto-unlock

KDE uses KWallet by default; archway disables it
(`~/.config/autostart/kwalletd6.desktop`, `Hidden=true`) in favor of
gnome-keyring as the single Secret Service. gnome-keyring usually auto-starts via
its own XDG autostart. To have it unlock at login, add to `/etc/pam.d/login`
(and your display manager's PAM file if you don't autologin):

```
auth       optional     pam_gnome_keyring.so
session    optional     pam_gnome_keyring.so auto_start
```

Verify the Secret Service is up: `just check secret-service`.

### niri portals (screen share / file dialogs)

niri works with the GNOME + GTK portals (installed in T3). If screenshare or
file pickers misbehave under niri, set a portal preference **for the niri
session** rather than system-wide — e.g. `~/.config/xdg-desktop-portal/niri-portals.conf`:

```
[preferred]
default=gnome;gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.ScreenCast=gnome
```

(KDE/Plasma uses its own `xdg-desktop-portal-kde` and needs nothing here.)

---

## 6. Why no boot splash (plymouth)?

`plymouth` was removed: it was installed but never wired into boot (no
mkinitcpio hook, no `splash` kernel param), and on NVIDIA a GPU stall behind the
splash looked like a "stuck" boot. archway shows the plain systemd boot log
instead — louder, but diagnosable.

---

## Capturing boot logs

The red/orange text at boot is the systemd journal at priority `err` (red) and
`warning` (orange). It's all saved:

```bash
journalctl -b -p err --no-pager        # red lines, current boot
journalctl -b -p warning --no-pager    # orange lines (includes errors)
journalctl -b -1 -p warning --no-pager # the PREVIOUS boot (e.g. one that crashed)
systemctl --failed                     # units that failed to start
systemctl --user --failed
coredumpctl list                       # crash dumps (KWin, Discord, …)
```

### Known noise you can ignore

- **`hs_err_pid*.log` / `java` coredumps** — the `ltex-ls-plus` language server
  crashing inside your editor. Unrelated to system stability; `.gitignore`d.
- **`drkonqi-coredump-processor@... failed`** — KDE's crash reporter choking on a
  backlog; a symptom of crashes (usually the KWin ones), clears once those stop.
- **`vdirsyncer.service failed`** — calendar sync; fails when its OAuth secret is
  missing/expired. Fix with `just secrets-edit vdirsyncer.env` or ignore.

### Worth investigating

Anything mentioning `kwin_wayland`, `nvidia`, `nouveau`, `drm`, `segfault`,
`dumped core`, or a service you rely on failing.

---

## 7. Update hygiene

- Update with `just update` (`pacman -Syu` + `yay -Syu`). Never partial-upgrade
  (`pacman -Sy <pkg>` without `-u`) — on a rolling release that's a classic way
  to break the graphics stack or initramfs.
- Keep `linux-lts` installed as a fallback kernel. If a new `linux` + nvidia
  combo ever fails to boot, pick the LTS entry in systemd-boot and recover.
  (`linux-lts` is deliberately absent from the package lists — it's a
  per-machine safety net, not a baseline requirement. `just audit` will show
  it as "untracked"; that's expected. Install it once with
  `sudo pacman -S linux-lts linux-lts-headers`.)
- After updates, `just doctor` and `just audit` confirm runtime + package state.

---

## Recovery model recap

| Problem class | Real recovery |
| --- | --- |
| Boot entry gone | `just fix-boot` (system or ISO) |
| Plasma-Wayland broken (NVIDIA) | use Plasma **(X11)** session; or `KWIN_DRM_NO_AMS=1` |
| Graphics broken after update | boot the LTS kernel entry; downgrade driver if needed |
| niri/DMS broken | log into Plasma from the greeter |
| Plasma also broken | TTY (Ctrl+Alt+F2); fix from the shell |
| Config/package drift | `just doctor` + `just audit` |

A fresh install + redeploy is the **last** resort: archinstall (ext4 + LUKS +
systemd-boot, pick the nvidia-open driver) → clone repo → `just setup` → restore
data from backups.
