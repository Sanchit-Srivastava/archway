# DMS and niri

Archway's full Linux installer requires an already working **Niri +
DankMaterialShell** session, normally supplied by archinstall. The DMS/niri
packages, compositor setup, and systemd binding come from the OS installer or
upstream DMS tooling. The login screen is independent: keep the working
display manager selected on the machine.

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

Initial-login fingerprint authentication belongs to the selected display
manager. DMS's Greeter settings apply to greetd and can modify its PAM
configuration; they do not configure Plasma Login Manager or SDDM. Leave them
alone when using another login manager. Never use fingerprint as the only
available authentication method; keep password login working.

## Installation checks

Before and after the core package upgrade, the full installer verifies:

- `niri` and `dms` are installed;
- `niri.service` and `dms.service` are active for the user;
- DMS has initialized its configuration directory;
- `/etc/systemd/system/display-manager.service` resolves to an installed
  service unit, rather than a missing file or a mask; and
- the selected display manager's service is loaded and active.

These checks are read-only and accept Plasma Login Manager, SDDM, greetd, or
another existing display manager. A failure stops the full installer with
recovery guidance; Archway never installs, switches, or rewrites the login
manager. The checks do not parse greeter-specific configuration or replace a
logout/login test after package changes.

`just dms-config` only checks for an active, initialized Niri+DMS session. It
does not require or inspect a particular display manager. A Niri/DMS session
added through the upstream installer can therefore keep the existing CachyOS
login manager.

## Login manager

Keep Plasma Login Manager or SDDM if either already works. Both can launch
Niri as well as Plasma; changing the login screen does not require changing
the desktop session. DMS can continue running inside Niri without DMS Greeter.

Archway leaves autologin, login usernames, and PAM configuration machine-local.
Configure Plasma Login Manager through KDE's **Login Screen** settings.
Autologin does not disable an existing disk-encryption prompt, and it may leave
KWallet locked until its password is entered. Keep screen locking and locking
on resume enabled, especially on a travelling laptop.

### DMS Greeter packaging

As checked in September 2026, DMS Greeter is a separate upstream component.
Arch's `dms-shell` package no longer contains the old bundled launcher:

```text
/usr/share/quickshell/dms/Modules/Greetd/assets/dms-greeter
```

Archinstall's Niri+DMS integration has written that path into
`/etc/greetd/config.toml`. A system can therefore retain a command pointing to
a file removed by a package upgrade. An older mismatch worked in the opposite
direction: DMS's greeter sync could rewrite the bundled path to
`/usr/bin/dms-greeter` without that executable being installed.

If choosing DMS Greeter, use the separate `greetd-dms-greeter-bin` package
(tagged release) or `greetd-dms-greeter-git` (development build), then follow
the [upstream setup instructions](https://danklinux.com/docs/dankgreeter/installation).
Current setup uses `dms-greeter install`; the old `dms greeter` command is a
deprecated alias. Do not run greeter installation or enablement commands when
keeping Plasma Login Manager or SDDM: those commands can switch the active
display manager. Do not copy an old wrapper or create a symlink to a missing
file as a repair.

References: [archinstall greeter setup](https://github.com/archlinux/archinstall/blob/master/archinstall/lib/profile/profiles_handler.py),
[Arch DMS package files](https://archlinux.org/packages/extra/x86_64/dms-shell/files/),
[DMS Greeter](https://github.com/AvengeMedia/dank-greeter).

### Switching from a broken DMS Greeter

This is a manual recovery procedure on the affected laptop, not an Archway
deployment step. A missing greeter executable does not require an OS reinstall.

Save work, switch to a TTY with **Ctrl+Alt+F3**, and log in normally. Check the
existing selection and whether Plasma Login Manager is already installed:

```bash
readlink -e /etc/systemd/system/display-manager.service
pacman -Q plasma-login-manager
systemctl show plasmalogin.service --property=LoadState --value
```

Current `plasma-meta` depends on `plasma-login-manager`. If the selection is
greetd, the package is installed, and the unit reports `loaded`, switch from
the TTY. Stopping a display manager can terminate its graphical session:

```bash
sudo systemctl disable greetd.service &&
sudo systemctl enable plasmalogin.service &&
sudo systemctl stop greetd.service &&
sudo systemctl start plasmalogin.service
```

If any command fails, stop and inspect the error; do not force-replace an
unexpected display-manager symlink. For an already installed SDDM, check the
`sddm` package and `sddm.service` instead, then use `sddm.service` in place of
`plasmalogin.service`. Choose only one login manager; do not run both sequences.

After logging in, verify the replacement (substitute `sddm.service` if chosen):

```bash
systemctl is-active plasmalogin.service
systemctl is-enabled plasmalogin.service
systemctl is-enabled greetd.service
readlink -e /etc/systemd/system/display-manager.service
```

Expect `active`, `enabled`, `disabled`, and the replacement's service-unit
path. Test logout/login, suspend/resume and unlocking, each desktop session
you use, and a reboot before removing any old packages. A disabled greetd can
remain installed without owning the login screen.

If the replacement fails, return to the TTY and inspect its journal:

```bash
sudo journalctl -b -u plasmalogin.service -n 80 --no-pager
```

To stop using the replacement, disable and stop its service. This leaves the
old greetd configuration untouched, but re-enabling greetd alone will not fix
a missing executable. For temporary access to an installed Plasma session,
stop the failed login manager and run the following **as your normal user**
from the TTY, without sudo:

```bash
/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland
```

See [Plasma Login Manager](https://wiki.archlinux.org/title/Plasma_Login_Manager),
[SDDM](https://wiki.archlinux.org/title/SDDM), and
[starting Plasma](https://wiki.archlinux.org/title/KDE#Starting_Plasma).

## Session recovery

For a DMS session problem:

```bash
dms doctor
journalctl --user -b -u niri.service -u dms.service -n 100
systemctl --user status niri.service dms.service
dms restart
just dms-config
```

Run `just dms-config` only from an active Niri+DMS session. If the login screen
cannot start, switch to a TTY and inspect the selected manager instead:

```bash
readlink -e /etc/systemd/system/display-manager.service
systemctl status display-manager.service --no-pager
```

Use that manager's journal and configuration for diagnosis. An unused
`/etc/greetd/config.toml` is not relevant when another login manager is selected.
