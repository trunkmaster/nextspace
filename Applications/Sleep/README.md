# Sleep Dock widget

A small beveled moon icon, drawn with AppKit like Battery. A single click opens
an application-modal countdown: **Sleeping in 5…** with **Cancel**. Cancel,
Escape, or closing the dialog prevents execution. At zero, the dialog closes
and the configured command starts asynchronously, once. Repeated clicks during
the countdown or while a command is running do not queue another invocation.

An autolaunched widget stays quiet; starting the application manually opens the
countdown. Window Maker's activation path and direct icon clicks are handled.
NextSpace includes an opt-in widget action hook. Sleep publishes an action-window
XID in `_NEXTSPACE_DOCK_ACTION_WINDOW` on its icon. After drag detection,
Workspace sends `_NEXTSPACE_DOCK_ACTION` to that window. Sleep receives it on a
separate X connection watched by the main run loop in normal and modal modes;
it does not poll, consume AppKit's event queue, or require a focusable document
window. Other Dock apps retain the user's single/double-click launch preference.
An older Workspace needs this small update loaded for single-click activation.
The countdown uses monotonic time and starts after the dialog appears. Settings
are reloaded before each countdown, then held fixed for that confirmation.

## Preferences

Edit `~/Library/Preferences/SleepWidget.plist` while the application is idle.
This separate configuration file is read directly before each countdown; AppKit
keeps its own UI defaults in Sleep.plist and cannot overwrite these settings:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Command</key>
  <array>
    <string>/usr/local/bin/doas</string>
    <string>-n</string>
    <string>/usr/sbin/zzz</string>
  </array>
  <key>CountdownSeconds</key>
  <integer>5</integer>
</dict>
</plist>
```

`Command` is an argument array. Its first element must be an absolute executable
path; subsequent elements are individual arguments, including arguments with
spaces. No shell or terminal is implicitly started. To deliberately use shell
syntax, configure `/bin/sh`, `-c`, and a command string explicitly. The command
runs as the desktop user. This application does not change doas/sudo rules.

FreeBSD defaults to `/usr/local/bin/doas -n /usr/sbin/zzz`; other builds default
to `/usr/bin/systemctl suspend`. Replace the array for a different setup. `-n`
requests noninteractive doas: an authentication/permission failure becomes a
visible error instead of waiting for an invisible password prompt. Standard
input is closed to interactive input. Command output goes to a private temporary
file, so a full pipe cannot block a command. A failed command displays its status,
up to 4 KiB of output, and the log path; successful command logs are removed.

`CountdownSeconds` must be a plist integer from 1 to 3600. Missing settings use
the defaults; invalid settings show an error without executing anything.

## Build and Dock setup

```sh
. /Developer/Makefiles/GNUstep.sh
gmake CC=clang
gmake install
/Applications/Sleep.app/Sleep -autolaunch YES
```

Dock its running icon and enable **AutoLaunch** in Workspace's Dock preferences.
Keep the saved Dock command `/Applications/Sleep.app/Sleep` without a permanent
`-autolaunch` argument; Workspace supplies that argument on automatic startup.
The custom live icon and bundled `Sleep.tiff` share the same drawing code. To
regenerate the bundled icon on an X display:

```sh
./Sleep.app/Sleep --render-icon Sleep.tiff
gmake install
```

## Verification

`harness/remote/sleep-widget-check.py` drives the actual installed application in
the isolated jail using XTEST, a real Workspace Dock, and a marker command. It
checks quiet startup, both cancellation paths, single-click activation, the
five-second deadline, duplicate clicks, invalid settings, and command errors.
It never invokes suspend. Actual machine suspension is left to an intentional
click after installation.
