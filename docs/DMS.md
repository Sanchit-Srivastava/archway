# Dux Shell (DMS) and niri

Archway's full Linux installer requires an already working **Niri +
Dux Shell (formerly DankMaterialShell)** session. The DMS/niri
packages, compositor setup, and systemd binding come from the OS installer or
upstream Dux Installer. The login screen is independent: the fresh-install
default is Plasma Login Manager with Plasma retained as a recovery desktop.
Keep a working existing manager rather than switching it automatically. See
[Reliable graphical login](LOGIN.md) for the installation and acceptance checks.

Archway applies personal settings to that working session. It does not run
`dms setup`, install DMS packages, or convert another desktop to DMS. Use the
upstream Dux Installer to add DMS to another system.

## Upstream installation and upgrades

Upstream renamed DankMaterialShell to **Dux Shell** in DMS 2.0. The installer
is now **`duxinstall`**, distributed through `https://install.duxlabs.dev`.
The shell command is still `dms` and the user unit is still `dms.service`.
The current Arch package is **`dux-shell`**, which provides `dms-shell` and
replaces the old `dms-shell`, `dms-shell-niri`, and `dms-shell-hyprland`
packages. Some upstream installation pages still show those older names.
For manual package installation use `sudo pacman -Syu dux-shell niri`; package
installation alone does not configure the session. Do not rename the CLI or
unit to `dux`.

On an installed Arch-family system, use the interactive upstream installer
as your regular user, before applying Archway:

```bash
curl -fsSL https://install.duxlabs.dev -o /tmp/duxinstall.sh &&
less /tmp/duxinstall.sh &&
sh /tmp/duxinstall.sh
```

Choose **Niri**, **Ghostty**, and systemd integration. Keep stable packages;
development builds are not required for the rebrand. Review the package and
configuration changes before accepting them. On a fresh conventional Niri
base, let upstream generate its Niri+DMS config (with its backup of the old
one); do not retain startup commands for a competing bar/notification daemon.
On an already customized session, review the config before choosing whether
to keep or replace it. Leave the optional **DMS Greeter** disabled
when keeping an existing login manager. Do not use `--all-features` for that
case: it also selects the greeter. Headless installation and config-replacement
flags are documented [upstream](https://duxlabs.dev/docs/duxinstall); Archway
does not invoke them automatically.

Log out and choose **Niri** at the existing login screen. This uses
`niri-session`, not a nested `niri` process. Confirm the Niri and DMS user
services are active, then run Archway. Do not add `dms run` to niri startup
when using the systemd service; that starts a second shell. The Dux Installer
does not supply every base-OS choice: see [Arch installation](INSTALL-ARCH.md)
for networking, audio, power management, and the login manager.

An existing working Niri+DMS installation does **not** need the installer
rerun merely because upstream changed names. Update through its existing
package source (`just update` for Archway), restart/log into DMS, and then
reapply preferences. Package updates and a working current session do not
prove the next login works: test logout/login before calling the upgrade done.

### Configuration compatibility

DMS 2.0 moves user config to `${XDG_CONFIG_HOME:-~/.config}/dms`, with matching
`dms` directories under the XDG state, cache, and data locations. DMS performs
the migration itself and leaves compatibility symlinks at the old
`DankMaterialShell` paths. Fresh installs need not have those old paths.
Archway and its Neovim theme prefer the new directory and fall back to an
existing legacy directory; they do not move or merge directory trees. The
repository's `dots/DankMaterialShell/` directory remains a source of portable
overlays, not a runtime directory to symlink into the home folder.

The shell's window app ID is now `dev.duxlabs.shell`; Archway's floating rule
also accepts the previous IDs. This is distinct from the `quickshell` layer
namespace, which has not been renamed. DMS CLI, IPC bindings, plugin IDs,
`dms-open.desktop`, and niri's `dms/` fragments retain their names.

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

The niri configuration targets **niri 26.04 or newer**. Its generated color,
layout, Alt-Tab, output, and cursor fragments are optional includes, so a
fresh setup does not fail before DMS generates them. The shipped binds and
window rules remain required. Invalid fragments still produce errors, and
Archway no longer hides niri's failed-config notification. Validate with
`niri validate` on the target or `just check-niri` in the repository.

DMS's GUI can also edit `dms/binds.kdl` and `dms/windowrules.kdl`. Reapplying
Archway resets these to the repository copies; use `just pull-dots` and review
the diff first if keeping GUI edits. Both deployment and import respect
`XDG_CONFIG_HOME`. Input preferences remain in Archway's main config rather
than automatically importing upstream's generated `dms/input.kdl`.

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

DMS 2.0 also stores docks and lock-screen widgets as arrays, and workspace
labels are now per-widget options. Archway does not overwrite those arrays.
For a fresh setup, disable the dock, enable workspace indices in the workspace
widget, and use the lock-screen editor to hide the date, media/status widgets,
and profile image and show the password field only while typing. Existing
settings are migrated by DMS. The overlay no longer re-adds retired global
keys after migration. Album-art accent is now `dashOptions.media.albumArtAccent`.

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
- the installed niri can parse Archway's configuration before it is copied;
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

**Plasma Login Manager is the recommended fresh-install default, not DMS
Greeter.** Use the distro's stable package and keep Plasma as a recovery
session. Keep SDDM if it already works; it is also a valid alternative for a
machine where Plasma Login Manager does not pass the login checks. Both can launch
Niri as well as Plasma; changing the login screen does not require changing
the desktop session. DMS can continue running inside Niri without DMS Greeter.

This choice avoids the concrete archinstall/DMS greeter packaging and
configuration mismatch described below. It is not a claim that Plasma Login
Manager is bug-free or that greetd itself is unreliable. The default process
keeps login independent of DMS updates and verifies each layer separately;
see [Reliable graphical login](LOGIN.md). DMS's in-session screen locker stays
available without DMS Greeter.

Archway leaves autologin, login usernames, and PAM configuration machine-local.
Configure Plasma Login Manager through KDE's **Login Screen** settings.
Autologin does not disable an existing disk-encryption prompt, and it may leave
KWallet locked until its password is entered. Keep screen locking and locking
on resume enabled, especially on a travelling laptop.

### DMS Greeter packaging

Dux Greeter (still the `dms-greeter` command) is a separate upstream component.
Arch's current `dux-shell` package does not contain the old bundled launcher:

```text
/usr/share/quickshell/dms/Modules/Greetd/assets/dms-greeter
```

Archinstall 4.5's Niri+DMS integration still writes that path into
`/etc/greetd/config.toml`; this affects fresh installations too. An existing
system can also retain a command pointing to a file removed by a package
upgrade. An older mismatch worked in the opposite
direction: DMS's greeter sync could rewrite the bundled path to
`/usr/bin/dms-greeter` without that executable being installed.

If choosing Dux Greeter, current upstream instructions use `dux-greeter-bin`
(tagged release) or `dux-greeter-git` (development build); older packages used
the `greetd-dms-greeter-*` names. Follow the
[upstream setup instructions](https://duxlabs.dev/docs/dms-greeter/installation).
Current setup uses `dms-greeter install`; the old `dms greeter` command is a
deprecated alias. Do not run greeter installation or enablement commands when
keeping Plasma Login Manager or SDDM: those commands can switch the active
display manager. Do not copy an old wrapper or create a symlink to a missing
file as a repair.

References: [archinstall greeter setup](https://github.com/archlinux/archinstall/blob/master/archinstall/lib/profile/profiles_handler.py),
[Arch Dux package files](https://archlinux.org/packages/extra/x86_64/dux-shell/files/),
[Dux Greeter](https://github.com/duxlabs-dev/dux-greeter).

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
niri validate
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

## Upstream references

Reviewed 2026-10-27 against the DMS 2.0 release and current documentation:

- [DMS 2.0 release and migration notes](https://github.com/duxlabs-dev/dux-shell/releases/tag/v2.0.0)
- [Dux Installer](https://duxlabs.dev/docs/duxinstall)
- [Arch package installation](https://duxlabs.dev/docs/dms/installation)
- [Current Arch package metadata](https://archlinux.org/packages/extra/x86_64/dux-shell/)
- [Configuration paths and service management](https://duxlabs.dev/docs/dms/managing)
- [Niri session setup](https://niri-wm.github.io/niri/Getting-Started.html)

The website can describe changes newer than the tagged release. Prefer the
actual installed package names and `dms --version` when diagnosing a machine.
