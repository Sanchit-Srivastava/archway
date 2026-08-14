# DMS and niri

Archway's full Linux installer requires an already working Arch installation
created with archinstall's **Niri + DankMaterialShell** profile. Archinstall
supplies the DMS/niri packages, compositor setup, systemd binding, greetd
service, and DMS greeter.

Archway applies personal settings to that working session. It does not run
`dms setup`, install DMS packages, or convert another desktop to DMS. Use the
upstream DMS installer to add DMS to another system.

## Applying Archway preferences

The full `just install` command applies DMS preferences in the same run. Start
it after logging into the initialized Niri+DMS session. To apply the settings
again later, run:

```bash
just dms-config
```

Archway manages:

- `dots/niri/config.kdl`;
- selected niri fragments under `dots/niri/dms/`;
- the small settings overlay at `dots/DankMaterialShell/preferences.json`;
- selected DMS plugins and their shared preferences.

DMS manages its complete `settings.json`, plugin database, cache, generated
colors and layout, session data, and machine-specific values. Archway merges
small overlays rather than replacing those files. It makes a one-time
`.pre-archway.bak` backup before the first merge.

Plugin settings use DMS's `plugin_settings.json` schema. Archway installs the
selected plugins first and then enables/configures them through the shared
overlay. DankScale is installed and enabled, but its account identity, active
account, Taildrop destination, polling/display preferences, and other runtime
state are not committed.

Configure `barConfigs` in DMS Settings. DMS stores the complete bar list and
widget arrangements in a JSON array, which cannot be safely merged one bar at
a time:

- move the main bar to the bottom and enable auto-hide if desired;
- place launcher, workspaces, and focused window on the left;
- place music, clock, weather, and Pomodoro in the center; and
- place tray, DankScale, KDE Connect, clipboard, CPU, notifications, battery,
  and control center on the right.

Also select Ghostty in DMS **Default Apps** and in DMS's terminal picker. The
Archway niri binding already launches Ghostty.

## Fingerprint authentication

Fingerprint enrollment and authentication remain manual. For the DMS lock
screen, use **Authentication Source: Auto**, leave **Use system PAM
authentication** disabled, enroll a fingerprint with the system's fprintd
tooling, and then enable DMS lock-screen fingerprint authentication. This lets
DMS use its separate lock-screen fingerprint path without changing greetd.

Initial-login fingerprint authentication is a separate setting under DMS's
Greeter page and can modify `/etc/pam.d/greetd`. Leave it disabled on the
archinstall Niri+DMS base unless the upstream DMS greeter packaging and
archinstall integration have been verified together. Never use fingerprint as
the only available authentication method; keep password login working.

## Installation checks

Before and after the core package upgrade, the full installer verifies:

- `niri` and `dms` are installed;
- `niri.service` and `dms.service` are active for the user;
- DMS has initialized its configuration directory;
- greetd is enabled and configured for the DMS greeter; and
- the greeter executable referenced by `/etc/greetd/config.toml` exists and is
  executable.

These checks are read-only. A failure stops the full installer with recovery
guidance; Archway never rewrites the display manager supplied by the OS
installer.

`just dms-config` only checks for an active, initialized Niri+DMS session. It
does not require or inspect a particular display manager. A Niri/DMS session
added through the upstream installer can therefore keep the existing CachyOS
login manager.

## Recovery

For a DMS session problem:

```bash
dms doctor
journalctl --user -b -u niri.service -u dms.service -n 100
systemctl --user status niri.service dms.service
dms restart
just dms-config
```

If the greeter cannot start, switch to a TTY with Ctrl+Alt+F3 and inspect:

```bash
sudo systemctl status greetd
sudo sed -n '/\[default_session\]/,/^\[/p' /etc/greetd/config.toml
```

The archinstall profile uses the wrapper shipped inside `dms-shell` at
`/usr/share/quickshell/dms/Modules/Greetd/assets/dms-greeter`. Do not run a full
`dms greeter sync` when it would rewrite a valid archinstall asset path to a
missing `/usr/bin/dms-greeter`.
