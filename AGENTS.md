# AGENTS.md — Archway coding-agent instructions

Archway is a public personal configuration-as-code repository for machines
running Arch Linux, CachyOS, or macOS.

## Development safety

The repository is edited on development machines but its Linux infrastructure
targets real Arch-family installations.

Never run these on a development machine:

- `install.sh` or `remote-install.sh`
- `infra/bootstrap.sh`, `infra/dotfiles.sh`, or other target infrastructure
- `just install`, `just install-minimal`, `just core`, `just extras`, or
  `just dms-config`
- boot, package, service, or secret recipes

Safe development commands:

```bash
just lint
just check-fmt
just test
shellcheck
just check-niri
just check-nvim
shfmt -d
```

Validate changes statically. `just test` may exercise read-only library helpers
against temporary fixtures; it must never source entry-point scripts or execute
target-machine behavior.

## Ownership boundary

The base OS installer owns:

- filesystem, encryption, snapshots, bootloader, and kernel;
- GPU and hardware drivers;
- repositories and mirrors;
- the selected graphical profile and display manager;
- networking, audio, and power-management baseline.

Archway must not duplicate those responsibilities.

Arch installations begin with `archinstall`. The default is KDE Plasma
(`plasma-meta`) with Plasma Login Manager, then the upstream Dux Installer
for Niri+DMS with its optional greeter disabled. Keep Plasma as a recovery
session; Niri+DMS remains the daily desktop. Preserve a working existing
manager such as SDDM rather than switching it automatically. The staged
verification process is in `docs/LOGIN.md`.
Archinstall 4.5's Niri+DMS profile has stale package and greeter
references; do not recommend it until a released fix is verified. CachyOS
installations use its graphical installer, KDE Plasma, and suggested defaults.

## Installation contract

The pasteable entry point is `remote-install.sh`, which clones the repository
and delegates to `install.sh`.

The normal `just install` contract requires an already working Niri +
Dux Shell session, supplied by the base OS or upstream Dux Installer. It
installs core, dotfiles, secrets, and extras, then applies portable DMS/niri
preferences and plugins in one pass. It checks the existing persistent
display-manager selection and its service state without requiring greetd or a particular
greeter. There is no intermediate reboot, resume state, or finish phase.

`just install-minimal` installs only core, dotfiles, and secrets. Use it on KDE
or another base that Archway must leave graphically untouched.

`just dms-config` may configure an active Niri+DMS session installed either by
archinstall or by the upstream Dux Installer (`duxinstall`). It must not install
DMS, switch the display manager, or require greetd.

## Package lists

- `infra/pkgs/core.txt`: reliable native packages; failure is fatal.
- `infra/pkgs/extras.txt`: optional native packages.
- `infra/pkgs/extras.aur.txt`: optional AUR packages.
- `infra/pkgs/tex.txt`: slow optional TeX toolchain.
- `infra/services/core.txt`: system services deliberately owned by Archway.
- `infra/services/user.txt`: user services deliberately owned by Archway.

One package per line. Ignore blank lines and `#` comments. Group by comment
headers and alphabetize within a group.

Gaming is outside Archway's scope. Do not add CachyOS repositories to Arch or
reimplement CachyOS gaming setup.

## Shell conventions

Scripts use:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Use `set -eEuo pipefail` when an ERR trap must be inherited.

- Quote variable expansions.
- Use `UPPER_SNAKE_CASE` for exported/global constants.
- Use `lower_snake_case` for locals.
- Prefer helpers from `infra/lib/common.sh`.
- Use `pacman -S --needed` for idempotency.
- Check before enabling services or replacing files.
- Never rewrite distro mirrors, repositories, boot, PAM, or driver state.
- Optional failures must not invalidate a completed core install.

## Secrets

This repository is public.

- Never print, log, or commit an age private key or decrypted secret.
- Never pass secrets in process arguments or ordinary environment variables.
- Secret targets use mode `0600`.
- Validate a candidate age key before replacing the installed key.
- Generated DMS runtime JSON is not committed because it may contain
  machine-specific identifiers.

## DMS

The base OS or upstream Dux tooling owns DMS/niri installation, setup, and
session binding. The machine's chosen display manager may differ from the
installer's original choice. Archway performs read-only session and login-service
checks; it must not install, enable, disable, restart, or reconfigure a display manager.
DMS Greeter is a separate upstream component, not a required part of DMS.
Autologin, login usernames, and PAM settings stay machine-local. DMS owns its
full runtime JSON. Archway owns only selected niri files and small portable
JSON overlays.

Do not restore full generated `settings.json` or `plugin_settings.json` files.

DMS 2.0 is branded Dux Shell. The CLI and service are still `dms` and
`dms.service`; the stable Arch package is `dux-shell` (provides `dms-shell`).
Runtime directories now use the name `dms`. Use `infra/lib/dms.sh` to resolve
the new config path with a legacy `DankMaterialShell` fallback; never implement upstream's
migration here. The repository overlay directory retains its historical name.
The new shell app ID is `dev.duxlabs.shell`, not the layer namespace
`quickshell`. Preserve legacy app-ID matches for older installations.

The Dux Installer is a separate manual base-desktop step, not part of Archway.
Do not run it on a development machine or automatically select its optional
greeter (`--all-features` includes it). Preserve an existing working login
manager. Current setup and upstream references are in `docs/DMS.md`.
