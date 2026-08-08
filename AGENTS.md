# AGENTS.md — Archway coding-agent instructions

Archway is a public personal configuration-as-code repository for machines
running Arch Linux, CachyOS, or macOS.

## Development safety

The repository is edited on development machines but its Linux infrastructure
targets real Arch-family installations.

Never run these on a development machine:

- `install.sh` or `remote-install.sh`
- `infra/bootstrap.sh`, `infra/dotfiles.sh`, or other target infrastructure
- `just install`, `just core`, `just extras`, `just dms`, `just finish`
- boot, package, service, or secret recipes

Safe development commands:

```bash
just lint
just check-fmt
shellcheck
shfmt -d
```

Validate changes statically. Do not execute target-machine behavior to test it.

## Ownership boundary

The base OS installer owns:

- filesystem, encryption, snapshots, bootloader, and kernel;
- GPU and hardware drivers;
- repositories and mirrors;
- the selected graphical profile and display manager;
- networking, audio, and power-management baseline.

Archway must not duplicate those responsibilities.

Arch installations always begin with `archinstall` and its Niri +
DankMaterialShell, conventional Niri, or KDE Plasma profile. CachyOS
installations use its graphical installer, KDE Plasma, and suggested defaults.

## Installation contract

The pasteable entry point is `remote-install.sh`, which clones the repository
and delegates to `install.sh`.

The explicit phases are:

1. `just install` — core, dotfiles, secure age-key onboarding, extras, DMS, and
   upstream `dms setup`.
2. Reboot and log into niri/DMS once.
3. `just finish` — secrets retry, portable DMS/niri preferences, plugins, and
   DMS restart.

There is no automatic resume or autostart state machine.

`just install-safe` installs only core, dotfiles, and secrets. The OS-provided
graphical profile is already a fully usable fallback.

## Package lists

- `infra/pkgs/core.txt`: reliable native packages; failure is fatal.
- `infra/pkgs/dms.txt`: optional native DMS/niri desktop packages.
- `infra/pkgs/extras.txt`: optional native packages.
- `infra/pkgs/extras.aur.txt`: optional AUR packages.
- `infra/pkgs/tex.txt`: slow optional TeX toolchain.
- `infra/pkgs/zotero.aur.txt`: slow optional Zotero install.
- `infra/services/core.txt`: only services deliberately owned by Archway.

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

Use native packages and upstream `dms setup`. DMS owns its full runtime JSON.
Archway owns only selected niri files and small portable JSON overlays.

Do not restore full generated `settings.json` or `plugin_settings.json` files.
