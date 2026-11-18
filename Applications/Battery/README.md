# Battery dock monitor (FreeBSD)

A 64×64 application icon, using a run-loop timer like Preferences' clock.
Every 30 seconds it launches `/usr/sbin/apm -abl` without a shell or a
blocking wait. The three output lines are AC status, battery state and
percentage (the order documented by the FreeBSD apm manual).

The battery fills from left to right: green above 20%, yellow at 11–20%, red
at 0–10%. A reported low/critical battery state also selects yellow/red.
A centered lightning bolt indicates AC power or charging; the tooltip gives
the detailed state. Failed, unsupported or malformed readings show `--`,
never a stale full battery. A five-second watchdog terminates a slow poll; it never starts
another while the previous task is outstanding. Refresh in the application
menu requests an immediate reading.

## Build and run

With the NextSpace development environment loaded:

```sh
gmake CC=clang
gmake install GNUSTEP_INSTALLATION_DOMAIN=USER
~/Applications/Battery.app/Battery -NXAutoLaunch YES
```

The Applications aggregate includes Battery on FreeBSD. A normal system
installation installs it alongside the other applications.

Drag its running icon into the Dock below Preferences, moving existing icons
down if needed. Set AutoLaunch in the Dock icon's settings to start it with
the desktop. Dock arrangement belongs to Workspace; this application does
not rewrite a running desktop's WMState preferences.

## Validation

```sh
cd Tests
gmake CC=clang
./obj/battery-status-test
```

The parser tests cover AC, charging, critical, zero charge, missing battery
(255), truncated input, invalid states and malformed output.

To render full/low/critical/unavailable fixtures without changing the real
battery state (requires an X display):

```sh
gmake -f GNUmakefile.render CC=clang
DISPLAY=:0 ./obj/battery-render-test /tmp/battery-states.png
```
