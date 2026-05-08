# Gaming on archway (NVIDIA + CachyOS repos)

archway is base Arch. The **CachyOS** and **Chaotic-AUR** third-party
repositories are NOT enabled by default — they are opt-in via
`infra/setup-repos.sh`. Once enabled, you get most of what CachyOS offers
(optimized kernel, gaming meta-packages, Proton builds, hardware detection)
without leaving Arch.

Nothing in this document is installed by default. Each section is opt-in.

---

## 0. Enable the third-party repos (prerequisite)

Run this once before installing anything below:

```bash
just setup-repos          # adds CachyOS + chaotic-aur to /etc/pacman.conf
```

This previously ran automatically during bootstrap but caused too much
friction (keyserver flakiness, upstream installer changes, mirror
outages). It is now strictly opt-in.

---

## 1. Hardware detection (chwd)

`chwd` (CachyOS Hardware Detection) is NOT installed by default. After
running `just setup-repos`, install it:

```bash
just setup-cachyos-extras  # installs cachyos-settings + chwd
```

Then detect and install matching driver profiles:

```bash
just hwdetect              # installs nonfree (NVIDIA) profiles automatically
# or
sudo chwd -l               # list available profiles for detected hardware
sudo chwd -a               # auto-install detected profiles (free + nonfree)
sudo chwd -i pci nvidia-dkms   # install a specific profile
```

For an NVIDIA GPU on Arch, `chwd` typically installs `nvidia-dkms`,
`nvidia-utils`, `lib32-nvidia-utils`, `nvidia-settings`, and configures
`mkinitcpio` early-KMS plus the modprobe options needed for Wayland.

After driver install, reboot.

---

## 2. CachyOS optimized kernel (optional)

```bash
sudo pacman -S linux-cachyos linux-cachyos-headers
# Then update bootloader entries (systemd-boot does it automatically on the
# next pacman -Syu via the kernel hook; verify with `bootctl list`).
sudo reboot
```

Available variants (pick one):

| Package                  | Notes                                                   |
| ------------------------ | ------------------------------------------------------- |
| `linux-cachyos`          | Default: BORE scheduler, BBR3, common patches           |
| `linux-cachyos-bore`     | Pure BORE                                               |
| `linux-cachyos-eevdf`    | Stock EEVDF, lighter patch set                          |
| `linux-cachyos-lts`      | Based on LTS kernel; safer fallback                     |
| `linux-cachyos-rt-bore`  | Real-time + BORE (audio production)                     |

Always keep `linux` (stock) installed as a fallback boot entry. Don't remove it.

---

## 3. Gaming meta-packages (CachyOS repo)

These are the same meta-packages CachyOS ships preinstalled. Install whichever
you want:

```bash
# Curated gaming bundle (Steam, Lutris, Gamescope, MangoHud, gamemode, etc.)
sudo pacman -S cachyos-gaming-meta

# Just the apps without scheduler/proton extras
sudo pacman -S cachyos-gaming-applications

# CachyOS-tuned Proton (alternative to Proton-GE)
sudo pacman -S proton-cachyos
```

To see what a meta-package pulls in before installing:

```bash
pacman -Si cachyos-gaming-meta | grep -A50 'Depends On'
```

### Manual minimal gaming set (if you don't want the meta)

```bash
sudo pacman -S steam lutris gamescope mangohud gamemode goverlay \
               wine wine-mono wine-gecko winetricks
```

---

## 4. Proton builds

| Source        | Package                  | Install                                    |
| ------------- | ------------------------ | ------------------------------------------ |
| CachyOS       | `proton-cachyos`         | `sudo pacman -S proton-cachyos`            |
| Chaotic-AUR   | `proton-ge-custom`       | `sudo pacman -S proton-ge-custom`          |
| GitHub direct | GE-Proton release tarball| Use `protonup-qt` (chaotic) or extract to `~/.steam/root/compatibilitytools.d/` |

Restart Steam after installing; pick the new tool under Steam → Settings → Compatibility.

---

## 5. Schedulers (optional)

CachyOS ships sched-ext userspace schedulers. They are NOT enabled by default;
you opt in per session.

```bash
sudo pacman -S scx-scheds
# Then enable one (e.g. scx_lavd is good for desktop/gaming):
sudo systemctl enable --now scx_loader.service
# or run ad-hoc for a session:
sudo scx_lavd
```

`ananicy-cpp` (auto-renice rules for games/compilers) is also available:

```bash
sudo pacman -S ananicy-cpp cachyos-ananicy-rules
sudo systemctl enable --now ananicy-cpp.service
```

---

## 6. Why these instead of pure Arch builds?

| Concern                  | Resolution                                                 |
| ------------------------ | ---------------------------------------------------------- |
| Trust                    | CachyOS + Chaotic are signed; widely used since 2021/2020  |
| Conflict with stock Arch | None - they only override packages that exist in stock     |
| Rollback                 | `pacman -S extra/<pkg>` to force the Arch version          |
| Drift                    | `just audit` flags installed packages not in repo lists    |

---

## 7. NVIDIA + Hyprland/Niri checklist

After `chwd` installs the driver:

1. Verify `nvidia_drm.modeset=1` is set:
   ```bash
   cat /proc/cmdline | tr ' ' '\n' | grep nvidia_drm
   ```
   If missing, add to `/etc/modprobe.d/nvidia.conf`:
   ```
   options nvidia_drm modeset=1 fbdev=1
   ```
   then `sudo mkinitcpio -P && reboot`.

2. Useful env vars (set in `~/.config/uwsm/env` or compositor session):
   ```
   LIBVA_DRIVER_NAME=nvidia
   GBM_BACKEND=nvidia-drm
   __GLX_VENDOR_LIBRARY_NAME=nvidia
   NVD_BACKEND=direct
   ```

3. For Steam/Proton, no extra env normally needed - the driver handles it.

---

## See also

- `infra/setup-repos.sh` — opt-in script that adds CachyOS + chaotic-aur repos
- `just setup-cachyos-extras` — installs cachyos-settings + chwd after repos are added
- [CachyOS package browser](https://software.cachyos.org/)
- [Chaotic-AUR package list](https://aur.chaotic.cx/packages)
