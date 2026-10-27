# Reliable graphical login

## Default

For fresh installations, use **Plasma Login Manager** for login, **Niri +
Dux Shell** for daily work, and **KDE Plasma** as an installed recovery desktop.
DMS Greeter is not part of this default. Plasma Login Manager is the
`plasma-login-manager` package and `plasmalogin.service`, not SDDM under a new
package name. Keep an already working SDDM rather than migrating merely to
match the fresh-install recommendation.

The reason is separation: updating or configuring the DMS shell should not
also change the program that gets you into the machine. Archinstall's old
DMS greeter path and upstream greeter-sync behavior have disagreed; the
[current packaging mismatch](DMS.md#dms-greeter-packaging) remains a reason
to avoid that route. Plasma Login Manager avoids this particular integration,
not every possible graphics or login failure. SDDM is the more established
alternative if Plasma Login Manager fails on a particular machine.

This choice is made in the **base OS installer**. Archway preserves the
selected manager and never switches it during install, sync, or preference
application. The checks below are run on the target machine, not a development
host. They are staged acceptance checks, not extra Archway install phases.

## 1. Establish the recovery desktop

On Arch, choose **KDE Plasma**, the recommended **plasma-meta** flavor, and
**Plasma Login Manager** in archinstall. The 4.5 Plasma profile already defaults
to that manager. On CachyOS, choose Plasma and retain its working distro-selected
manager; prefer Plasma Login Manager when offered. Use the remaining choices
in [INSTALL-ARCH.md](INSTALL-ARCH.md) or [INSTALL-CACHYOS.md](INSTALL-CACHYOS.md).

Before adding Dux or applying Archway:

- Log into Plasma with a password, log out, and log in again.
- Reboot and repeat password login. Confirm networking, audio, and displays.
- Verify normal-user password access on a TTY (**Ctrl+Alt+F3**, sometimes with
  **Fn**). Run `exit` when finished so the TTY is not left as an unlocked shell.
- Keep autologin and login-screen fingerprint customization off until the
  baseline works. Do not edit PAM or add third-party greeter themes as part of
  the baseline.

For the Plasma Login Manager default, inspect:

```bash
pacman -Q plasma-login-manager
readlink -e /etc/systemd/system/display-manager.service
systemctl is-enabled plasmalogin.service
systemctl is-active plasmalogin.service
systemctl get-default
```

Expect the selected unit to end in `plasmalogin.service`, with `enabled`,
`active`, and `graphical.target`. For a retained SDDM installation, substitute
`sddm` and `sddm.service`. If these disagree, stop and repair the base rather
than layering DMS on top. Record the selected manager for the next step.

## 2. Add Niri+DMS without replacing login

Run the interactive [Dux Installer](DMS.md#upstream-installation-and-upgrades)
as your normal user. Choose Niri, Ghostty, stable packages, and systemd
integration. Leave **DMS Greeter disabled**; do not use `--all-features`, run
`dms-greeter install`, or enable greetd. Inspect the final selections instead
of assuming an installer's current defaults match this guide.

After installation, repeat the selection and service checks above. The login
manager must be unchanged. Before logging out, check that Niri's packaged
session entry and launcher exist:

```bash
test -r /usr/share/wayland-sessions/niri.desktop
command -v niri-session
```

A successful `test` prints nothing and exits zero. The packaged Niri session
uses `Exec=niri-session`. Select **Niri** at the existing login screen; do not
use a nested compositor inside Plasma as the test. In Niri:

```bash
systemctl --user is-active niri.service dms.service
niri validate
dms doctor
```

Both services should be active, and config validation must succeed. Review
any doctor findings before proceeding. Log out into the same login screen,
then log into **Plasma** again. Confirm that Plasma still works and DMS is not
starting over it; the shell should be attached to the Niri session, not every
graphical session. Test with only one graphical session for this user open
at a time, because the systemd user manager is shared between sessions.

### Older DMS service enablement

The current installer attaches DMS to `niri.service`. Do not instead run
`systemctl --user enable dms.service`: the shipped unit's install target is
`graphical-session.target`, which can start DMS in Plasma too. When setting
up the binding manually, use `dms systemd enable --compositor niri`, without
`--now` while in Plasma.

On an existing installation where DMS was globally enabled for this user,
correct that binding manually, as the normal desktop user:

```bash
systemctl --user disable dms.service &&
dms systemd enable --compositor niri
```

This removes the old per-user enablement before adding the Niri binding; it
does not change the system login manager. Without `--now` it also does not
stop a running shell. Log out and test both desktops again. `dms systemd status`
reports compositor bindings but does not detect every legacy global startup
path; if DMS still starts in Plasma, inspect user/system-wide autostart and
service configuration rather than assuming this correction covered it.

## 3. Apply Archway, then test the result

Log back into Niri+DMS and run the full installer from the README. If Archway
is already installed and only its desktop preferences need applying, use
`just dms-config` instead. Neither command selects a login manager.

Before calling the installation or a login-related upgrade complete:

- Repeat the selected-manager checks; the selection must be unchanged.
- Test logout and password login into **both Niri and Plasma**.
- Test suspend/resume and screen unlock in the desktop you use.
- Reboot and confirm a successful login into Niri, with Plasma still available.

Keep Plasma installed and retain any old greeter packages/configuration until
these tests pass. Customize autologin or fingerprint access afterward, one
change at a time, retaining a working password path. DMS's screen locker is
separate from DMS Greeter and remains usable with Plasma Login Manager.

The installer's loaded/active service checks are useful preflight checks, not
proof that the next login will work. A running daemon can still reference a
removed greeter executable. The logout/reboot checks cover that gap.

## Recovery

- **Login screen works, Niri or DMS does not:** select Plasma at login and
  inspect the [session diagnostics](DMS.md#session-recovery). Do not reinstall
  or replace the login manager to fix a desktop-shell configuration error.
- **Login screen does not work:** use the tested TTY/password path. Inspect
  `systemctl status display-manager.service --no-pager` and the selected
  manager's journal. For the default, use
  `sudo journalctl -b -u plasmalogin.service -n 80 --no-pager`.
- **Existing broken DMS Greeter:** use the conditional
  [manual switch procedure](DMS.md#switching-from-a-broken-dms-greeter).
  Do not blindly force an alias, run two managers, or stop one from a terminal
  containing unsaved graphical work. A previously broken greetd is not a
  working rollback just because its package remains installed.

Plasma is a fallback for a Niri/DMS session failure, not for a broken GPU
stack or unbootable system. Keep installation media and backups available.

## Sources

Reviewed 2026-10-27; the process still requires testing on the target hardware.

- [Archinstall 4.5 Plasma package and greeter defaults](https://github.com/archlinux/archinstall/blob/4.5/archinstall/default_profiles/desktops/plasma.py)
- [Arch plasma-meta dependencies](https://archlinux.org/packages/extra/any/plasma-meta/)
- [Plasma Login Manager package](https://archlinux.org/packages/extra/x86_64/plasma-login-manager/)
- [Plasma Login Manager setup](https://wiki.archlinux.org/title/Plasma_Login_Manager)
- [Niri 26.04 session entry](https://github.com/niri-wm/niri/blob/v26.04/resources/niri.desktop)
- [Dux Installer options](https://duxlabs.dev/docs/duxinstall)
- [DMS 2.0 compositor-specific service binding](https://github.com/duxlabs-dev/dux-shell/blob/v2.0.0/core/internal/config/session_units.go)
- [DMS 2.0 systemd unit](https://github.com/duxlabs-dev/dux-shell/blob/v2.0.0/assets/systemd/dms.service)
