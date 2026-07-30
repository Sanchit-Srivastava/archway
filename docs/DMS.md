# DMS and niri

DMS and niri are optional. KDE Plasma remains the reliable fallback session.

## Installation

```bash
just dms
```

Archway installs native repository packages and runs:

```bash
dms setup
```

That upstream command creates only missing or empty compositor integration
files.

Log out, select niri in the display manager, and log in once. DMS then creates
its current versioned runtime settings.

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
journalctl --user -u dms -n 100
dms restart
just dms-config
```

If DMS cannot start, select KDE Plasma at the login screen. Repair DMS from
KDE without changing the OS or bootloader.

