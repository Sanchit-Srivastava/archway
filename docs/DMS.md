# DMS and niri

DMS and niri are optional. The graphical profile installed by the OS remains
the reliable fallback.

## Installation

```bash
just dms
```

Archway installs only the native DMS/niri package set and runs:

```bash
dms setup
```

That upstream command creates compositor integration files. Choose **niri** and
**systemd integration** when prompted. Archway then binds `dms.service` to
`niri.service` and applies its niri config, which deliberately contains no
second manual `dms run` startup.

Log out, select niri in the display manager, and log in once. DMS should start
with the niri systemd session. DMS can render from built-in defaults without
writing `settings.json`; `just dms-config` initializes that file from the
portable overlay when necessary, and DMS expands it to its current schema.

## Applying Archway preferences

```bash
just dms-config
```

Archway owns:

- `dots/niri/config.kdl`;
- selected niri fragments under `dots/niri/dms/`; and
- small portable overlays under `dots/DankMaterialShell/`.

DMS owns its complete `settings.json`, plugin database, cache, generated
colors/layout, and machine-specific values. Archway merges portable preferences
rather than replacing those files.

`just dms-config` makes a one-time `.pre-archway.bak` backup before the first
merge and is safe to rerun.

## Recovery

```bash
dms doctor
journalctl --user -b -u niri.service -u dms.service -n 100
systemctl --user status niri.service dms.service
systemctl --user list-dependencies niri.service
dms restart
just dms-config
```

If `dms.service` is not listed under `niri.service`, repair the session binding:

```bash
systemctl --user add-wants niri.service dms.service
```

If DMS cannot start, select the original base session at the login screen.
Repair DMS from the original Niri or Plasma environment without changing the
OS, display manager, or bootloader.

## Display manager

Archway does not install or switch greeters. Keep the display manager selected
during the base OS installation. A display manager can discover both the Niri
and Plasma Wayland session entries, so installing another desktop does not
require replacing it. Only one `display-manager.service` should be enabled.
