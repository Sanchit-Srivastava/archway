# Simplification (executed)

> **Status: DONE.** This was a proposal; the cuts below were carried out and
> verified (shellcheck + shfmt clean, `just doctor` passes on the live machine).
> Kept as a record of what changed and why.
>
> **Outcome:**
> - `bootstrap.sh`: **1253 → ~810 lines** (removed systemd-boot duplication,
>   fragile PAM `awk`-surgery, portals config, DM-swap machinery, polkit no-op,
>   ESP pre-flight scan, per-tier markers, ASCII banners; trimmed installer
>   fallbacks). `enable_multilib` kept (lib32 dependency).
> - `doctor.sh`: **860 → ~500 lines, 39 → 15 checks** (dropped every bare
>   `command -v` package check, the tier subsystem, and the hand-maintained
>   `--list`; kept runtime/service/drift/boot checks; `--list` now generated).
> - Deleted `setup-nvidia.sh` (solved a non-problem; NVIDIA now via archinstall +
>   docs). Kept `fix-boot.sh` as the one sanctioned repair tool.
> - Added `plasma-x11-session` (reliable Plasma fallback that dodges the
>   NVIDIA-Wayland KWin bug).
> - PAM (fingerprint/keyring) and niri portals moved to documented manual steps
>   in `docs/STABILITY.md` §5.
> - Repo is now DM-agnostic (accepts whichever DM archinstall enables).

## Why this existed

archway's stated goal is a **thin layer on top of a default archinstall KDE
Plasma system**, to *reduce* maintenance. In practice the repo drifted into
re-doing work archinstall already does, plus surgical edits to `/etc` that are
fragile on a rolling release. The result is ~3,000 lines of bash that must stay
correct against pacman/systemd churn and that can't easily be audited by hand.

A concrete illustration of the drift: the `setup-nvidia.sh` script added last
session targets a "nouveau in initramfs" race that, on the actual machine, is
already neutralized by `nvidia-utils`'s built-in nouveau blacklist — and it does
**not** fix the real KWin crash (a KWin-6.7 / nvidia-610 version bug). So it's
effort solving a non-problem. That is the pattern we're correcting.

This plan keeps **Job A** (install my packages, link my dotfiles, deploy my
genuinely-custom configs) and removes **Job B** (re-automate OS install + encode
a script for every issue ever hit).

## Target outcome

| File | Now | After | Cut |
| --- | ---: | ---: | ---: |
| `infra/bootstrap.sh` | 1253 | ~400 | ~850 |
| `infra/doctor.sh` | 860 | ~250 | ~610 |
| `infra/setup-nvidia.sh` | ~440 | 0 (deleted → doc) | ~440 |
| `infra/fix-boot.sh` | ~230 | 0 or kept (your call) | up to 230 |
| **Total** | **~2780** | **~650–900** | **~1900–2100** |

Nothing about *which software gets installed* changes. We're removing
duplication, fragile `/etc` surgery, and validation noise — not features.

---

## Part 1 — `bootstrap.sh` (1253 → ~400)

### KEEP (the legitimate thin-layer core)

| Function | Lines | Why keep |
| --- | --- | --- |
| log helpers, `die`, `array_contains`, `on_exit` | 24–80 | trivial plumbing |
| `check_prerequisites` (minus ESP scan) | 89–114, 133–135 | Arch/network/sudo/disk sanity |
| `refresh_mirrors` | 154–168 | useful on fresh installs, degrades gracefully |
| `refresh_keyring_and_upgrade` | 179–187 | correct cold-start `-Syu` |
| `install_yay` | 218–244 | building yay is genuinely our job |
| `install_pacman_packages` (slimmed) | 250–374 | **core job**; trim per-package `pacman -Si` loop + one-by-one fallback (~80 lines) since `pacman -S --needed` already reports failures |
| `install_aur_packages` (slimmed) | 376–434 | same; trim the diagnostics block yay already prints |
| `enable_services` (minus DM branch) | 476–509 | enabling from a list is core |
| `configure_keyd` | 841–873 | real custom config, clean whole-file copy |
| `set_default_shell` | 977–993 | `chsh` is our job |
| `run_tier`, `usage`, `parse_args`, `main` (slimmed) | 1001–1250 | the spine; collapse dual marker files |

### CUT — duplicates archinstall (safe; archinstall already did it)

| Function | Lines | Reason |
| --- | --- | --- |
| `configure_systemd_boot` | 768–835 | archinstall ran `bootctl install` + registered the EFI entry. Re-running it is duplication and is the riskiest code (writes to ESP). |
| `ensure_loader_conf` | 745–766 | archinstall wrote a working boot config; UKIs auto-discover, need no default-entry handholding. |
| `has_boot_entry` | 728–739 | its "no entry" branch can't fire on a UKI install. |
| `detect_esp_mount` | 710–719 | only used by the boot funcs above. |
| ESP scan inside `check_prerequisites` | 115–132 | validates an ESP archinstall already mounted; duplicates `detect_esp_mount`. |
| `is_display_manager` | 443–452 | machinery for a DM-swap that never happens. |
| `enable_display_manager` | 455–474 | archinstall KDE already enables `sddm.service`. |
| `enable_user_services` → pipewire/portal lines | 514–518 | the PipeWire stack is enabled by its own install under Plasma. Keep only `vdirsyncer.timer` (and ideally move it to a user-services list file). |
| `enable_multilib` | 189–212 | **KEPT, on reflection** — multilib is a hard dependency for `lib32-nvidia-utils` and Steam, and this `sed` is idempotent + self-verifying (re-checks `pacman-conf` after). Deleting it risks a fresh install lacking 32-bit support for marginal gain. It's the one `/etc` edit that earns its place. |

> Also: remove `sddm` from `infra/services/30-desktop.txt` (archinstall enables it).

### RESOLVED — greeter / display manager (decision made)

**Decision: stay on SDDM, but make the repo DM-agnostic.**

- `fractal` is on SDDM (enabled + running). Keeping SDDM = zero change to existing machines.
- archinstall's KDE profile now defaults to **Plasma Login Manager** (`plasmalogin`, an SDDM fork), not SDDM. A *fresh* install may therefore have `plasmalogin` enabled instead. The repo must not fight whichever DM archinstall enabled.
- `ly`/`greetd` were considered and rejected: "lighter" is irrelevant for a 3-second boot greeter, and `greetd` would *add* new `/etc/greetd/config.toml` glue — the exact Job-B complexity we're removing. They're also weaker for the projector/eduroam use case that justifies keeping KDE.
- Plasma Login Manager is a reasonable *future* migration once battle-tested; not during a stability push (it's new, and this is an NVIDIA machine).

**Implication for the cuts:** deleting the DM-swap machinery (`is_display_manager`, `enable_display_manager`) and not enabling a DM from the repo is now *more* justified, not less — the repo simply accepts archinstall's choice. SDDM autologin glue stays (the `autologin.conf` format is shared with plasmalogin since it's a fork).

### ADD — Plasma X11 fallback session (approved)

- Add `plasma-x11-session` to `infra/pkgs/30-desktop.txt`. This provides a
  **"Plasma (X11)"** session at the greeter, which sidesteps the NVIDIA-Wayland
  KWin crash entirely — the robust fallback for presenting/eduroam. Currently
  only Wayland sessions are installed, so this gap is real.

### CUT / CONVERT-TO-DOC — fragile `/etc` surgery (highest-risk code)

| Function | Lines | Mutates | Reason |
| --- | --- | --- | --- |
| `configure_pam_keyring` | 536–588 | `/etc/pam.d/login`, `/etc/pam.d/sddm` | `awk`-rewrites PAM + `.backup.DATE` litter. KDE's kwallet already covers keyring UX; if you want gnome-keyring, it's a documented manual edit. |
| `configure_pam_fingerprint` | 590–629 | `/etc/pam.d/system-auth`, `system-local-login` | **Riskiest in the repo** — editing `system-auth` with `awk`; a `pambase` update can make the match stale and **lock you out**. → doc (`fprintd` setup is a one-time manual step). |
| `configure_pam_dms` | 631–671 | creates `/etc/pam.d/dankshell` | DMS-specific glue; belongs in `install-dms.sh` or a doc, not core bootstrap. |
| `configure_portals` | 677–703 | `/etc/xdg/.../portals.conf` | system-wide `default=gnome` only matters once niri (T4) is used; move to a niri-scoped config or doc. |

### CUT — dead / no-op

| Function | Lines | Reason |
| --- | --- | --- |
| `configure_polkit` | 879–892 | installs/edits nothing; just `mkdir` + two log lines. |
| `on_error` ASCII banner | 49–67 | decorative; collapse to two `log_fatal` lines. |

### DECISION NEEDED — `configure_sddm_autologin`

- Lives in **two** places: `bootstrap.sh:898–971` **and** `install.sh:222–262`
  (duplication the first audit didn't flag).
- 74 lines of session-probing to write a 5-line file.
- **Options:** (a) keep one copy (in `install.sh`, since autologin is an
  install-time choice) and delete the bootstrap copy; (b) reduce both to a
  documented 5-line snippet. **Recommend (a).**

---

## Part 2 — `doctor.sh` (860 → ~250, 39 → ~18 checks)

**Litmus test:** *if a failing check's only fix is "Install: sudo pacman -S X",
delete it* — `--audit-packages` already proves packages are present. Keep doctor
for **runtime state, config/symlink drift, and boot safety**.

### KEEP (~18 — catch real, recurring problems)

- **Service enable-state** (cheap `is-enabled`, genuinely gets left off):
  `networkmanager`, `bluetooth`, `udisks2`, `polkit`, `accounts-daemon`, `keyd`
- **Runtime desktop facts** (the real flakes, not in any package list):
  `pipewire`, `wireplumber`, `xdg-portal`, `polkit-agent`, `secret-service`
- **Config / symlink drift** (clobbered by pacman or stray real files):
  `pam-keyring`*, `portal-config`*, `dotfiles`, `starship-config`, `environment-d`
- **Boot safety net:** `boot-entry` (keep the fallback sub-check)

> *`pam-keyring` and `portal-config` only stay relevant if we keep the
> corresponding configs. If §1 moves PAM/portals to docs, drop these two checks
> too — keeping ~16.

### DROP (~21 — noise)

- **All bare `command -v` tool checks** (12): `starship`, `zoxide`, `eza`,
  `bat`, `fzf`, `fd`, `ripgrep`, `lazygit`, `zsh`, `yay`, `terminal`,
  `file-manager` — `--audit-packages` covers these.
- `wayland-tools` (three `command -v` in a trenchcoat), `niri`, `plasma`, `dms`
  ("is my compositor installed" is answered by the fact you're running it).
- `pipewire-pulse` (collapses into pipewire/wireplumber signal).
- `user-services` (subsumed by the active-state checks).
- `zotero`, `zotero-mcp` (fragile profile-glob greps; if wanted, move to a
  separate `just`-invoked research check).
- `systemd-boot` (its bootable-entry assurance overlaps `boot-entry`).

### Infrastructure trims

- **Remove the tier system** (`CHECK_TIERS`, `tier_ok`, `gated_check`,
  `--tier`, `--up-to`, the `planned` pre-count): a second taxonomy to maintain
  in lockstep for marginal benefit on a single-user validator.
- **Drop or generate the 58-line `--list` block** (it's a 3rd place to keep in
  sync with the ID map + check bodies).
- **Keep** `run_check` + TAP output + `--audit-packages` (this is the
  highest-value feature; lean into it).

---

## Part 3 — the two new scripts (reconsidered)

### `setup-nvidia.sh` → **DELETE, replace with docs**

- It targets nouveau-in-initramfs, which is already neutralized by
  `nvidia-utils` on the real machine, and it does **not** fix the actual KWin
  crash (version bug). Net value ≈ 0 for ~440 lines of `sed` surgery on
  `mkinitcpio.conf`.
- Replace with a short `docs/STABILITY.md` section: pick `nvidia-open` in
  archinstall; the `-dkms` package + `nvidia-utils` handle blacklist + initramfs
  rebuild; if KWin/Plasma-Wayland crashes, it's a known driver bug → use the X11
  Plasma session or `KWIN_DRM_NO_AMS=1` (see Part 4).

### `fix-boot.sh` → **YOUR CALL (lean: keep as the one repair script)**

- It's mostly ceremony around `bootctl install`, **but** boot-bricking is
  high-stakes and the live-USB recovery flow is genuinely fiddly to remember.
- **Recommend:** keep it as the *single* sanctioned repair tool (not part of
  normal install), or reduce to a documented `bootctl install` snippet if you'd
  rather hold zero recovery scripts. Either is defensible; I lean keep.

### doctor checks added last session

- `nvidia-initramfs`: flags a real-but-inert condition. **Demote/redefine** — it
  doesn't catch the actual crash. Either drop it, or repoint it at the genuine
  signal (KWin coredumps). Low priority.
- `boot-entry`: **keep** (the fallback sub-check is cheap and high-value).
- plymouth removal from `30-desktop.txt`: **keep** (already done; correct).

---

## Execution order (after approval)

Small, reviewable commits, each verified with `shellcheck` + `shfmt`:

1. Delete fragile PAM surgery (`configure_pam_*`) + move to docs. *(highest risk removed first)*
2. Delete systemd-boot duplication (`configure_systemd_boot`, `ensure_loader_conf`, `has_boot_entry`, ESP scan, `detect_esp_mount`).
3. Delete DM-swap machinery + `sddm` from services list; trim `enable_user_services`.
4. Delete `enable_multilib` (+ document the archinstall checkbox); delete `configure_polkit`; de-dup `configure_sddm_autologin`.
5. Slim the two installers + collapse marker files + `on_error` banner.
6. `doctor.sh`: drop the ~21 noise checks + tier system + `--list`; keep lean set.
7. Delete `setup-nvidia.sh` → fold into `docs/STABILITY.md`. Decide `fix-boot.sh`.
8. Reconcile docs (SETUP/GAMING/STABILITY/AGENTS) to the slimmer reality.

## Risks & how we de-risk

- **These scripts run on the target laptops, not here.** We verify statically
  (shellcheck/shfmt) only; you do the live run.
- **The big behavioral assumption:** that archinstall (KDE profile, systemd-boot,
  multilib checkbox) already did the boot/SDDM/multilib setup. This held on
  `fractal` (boot entry + fallback present, sddm enabled). It should be
  re-confirmed on the next fresh install before fully trusting the cuts.
- **Reversibility:** every cut is in its own commit, so anything can be reverted
  cleanly if a fresh install reveals archinstall didn't cover it.

## Open decisions for you

1. `fix-boot.sh`: keep as the one repair script, or reduce to a doc snippet?
2. `configure_sddm_autologin`: keep one copy (in `install.sh`) or doc-ify both?
3. Keep `pam-keyring`/`portal-config` doctor checks if their configs move to docs?
   (i.e. are you keeping gnome-keyring + niri portal config as code, or as manual steps?)
