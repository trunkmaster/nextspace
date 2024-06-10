# 0.95: changes since 0.90

STOPPED ON COMMIT 326ed98c42fc6e0abee6e8a4e2cef89cd29c132c

- /etc/profile.d/nextspace.sh: fixes to development and user environment settings
- Fixes to package installation of Xorg (Xavier Brochard <xavier@alternatif.org>)
- Frameworks/DesktopKit/NXTSavePanel.m (runModalForDirectory:file:): center panel on display if there's no saved frame yet. Fixes issue #295.
- Use forked and simplified GNUstep Back ART backend with enhancements. I hope it's temporary solution for Xorg - next big would be a switch to Wayland.
- SELinux policies support: adds policies, changes to the spec and to the install script (Frederico Munoz <fsmunoz@gmail.com>)

## Terminal

- Added "Paste Selection" menu item (OnFlApp <onflapp@gmail.com>).
- Added support for setting title via xterm escape sequence (OnFlApp <onflapp@gmail.com>).
- Use shell configured in preferences if "Default Shell" option was set. Open new window with shell and send command to that shell for "New Window" and "Default Shell" case.

## Workspace

- Don't create launching icon if WM name is empty; change WM icon only of supplied path is not empty.
- Adedded and implemented "Open in Workspace" service (OnFlApp <onflapp@gmail.com>)
- Fixes to keyboard layout changes and app icon badge display
- Don't show keyboard layout badge on appicon if single keyboard layout was configured.
- Continued fixing of focus problems - it still happens occassionally.
- "Hide" menu item: treat Workspace application specially - set focus to main menu before windows hiding, do not hide main menu, do not change focus to other app after windows hiding.
- Don't focus hidden window after workspace switch.
- Don't set focus to GNUstep and Withdrawn (dockapp) windows. GNUstep sets focus by itself, dockapp windows is not intended to be focused by design (fixes focus flickering of Workspace during startup if dockapp is autolaunched).
* Switch to Core Foundation
- WINGs data structures and supporting functions were completely replaced by CoreFoundation counterparts.
- Notifications between Objective-C and C parts of Workspace were implemented with bridge between NSNotificationCenter and CFNotificationCenter. Internal Window Manager's notifications processed by CFNotificationCenter.
- Window Manager: implemented CFRunLoop based event handling - use CFFileDescriptor to monitor X and inotify events.
- Window Manager: implemented handling of _NET_REQUEST_FRAME_EXTENTS message.

```
commit efde696b585aff139226360b0f8fb222023a09a6
Author: Sergii Stoian <stoyan255@gmail.com>
Date:   Thu Nov 26 12:59:38 2020 +0200

    * Applications/Workspace/WM/src/event.c: implement CFRunLoop based
      event handling - use CFFileDescriptor to monitor X events.
    * Applications/Workspace/Workspace_main.m: change WM dispatch queue
      type to DISPATCH_QUEUE_CONCURRENT - it's mandatory to make
      CFRunLoop suff working. Use new WMRunLoop instead of EventLoop.
```

Major part of Workspace WM (formerly WindowMaker) was refactored and rewritten to ged rid of most WINGs data structures. That was my test and proof-of-concept subproject. I conside
r it successful and decide to merge into master.
    
Northworthy changes:
    
- Plenty of functions were renamed into the form of Objective-C world with static functions prefixed by "_" symbol.
- Notifications were renamed in style of Appkit notifications prefixed by "WM".
- Removed WM's blocking event loop - use CFRunLoop to manage Xlib events, timers, notifications etc. Animations became more smooth and nice looking without freeze or speedup.
- WM's defaults stored on contains only settings which differ from default values.
- WM's defaults now stored in ~/Library/Preferences/.NextSpace in XML format.
- CFStrings with UTF-8 encoding now used whenever it's appropriate.
- Adopted usage of many CoreFoundation data structures (CFArray, CFDictionary, CFData, CFPropertyList...)
- Interconnection between Workspace and WM now possible with CFNotificationCenter and NSNotificationCenter. Potentially it's possible to implement notification handling for any Obj
ective-C application by WM. For example, WM can observe NSApplicationDidFinishNotification to make updates in its data or perform some actions.
- Implemented handling of _NET_REQUEST_FRAME_EXTENTS message - works better with GNUstep Backend code and logic.
- Initial configuration was replaced from autotools to CMake as more clean and simple method for 'libwraster', 'Workspace/WM'.
- A lot of Workspace+WM.[hm] functions were moved into files located in Workspace/WM. More to come.
- Workspace/WM defaults handling now self-contained - no need to have files inside ~/Library/Preferences - files are created and removed if needed.
    
Major additions to Apple's CoreFoundation:

- CFFileDescriptor - doesn't exists in opensource version of CoreFoundation. Thanks to http://www.puredarwin.org project - I've grabbed and enhanced it to work on my current setup. In Workspace/WM CFFileDescriptor is used to track Xlib and Linux inotify events.
- CFNotificationCenter - missed from Apple's sources except header file - I've used Stuart Crook implementation found on GitHub, fixed, tested and used for notifications delivery inside WM and between WM and Workspace. Works good.

# 0.90: changes since 0.85

## Login

- Some reengeneering of application was done.
- Return code of Workspace application handled specifically: if `11` returned Login execute shutdown procedure without panel displayed; if `12` returned - executes reboot procedure.
- Fixed bug specific to Linux child processes handling: by default SIGCHLD singnal handler is set to `SIG_IGN`. In this case `waitpid()` returns `-1` with error explained as "No child process" - waitpid looses tracked child proces by some away. To prevent ot from happening signal handler should be set to `SIG_DFL`.
- Start sequence was changed: Login completely handles Xorg start and stop; loginwindow.service now handles only Login (doesn't kill Xorg on service stop).
- Defauls splitted into system (/usr/NextSpace/Preferences/Login) and user ($HOME/Library/Preferences/.NextSpace/Login). User defaults is a place were login/logout hooks are placed by "Login Preferences".

### Workspace

- Workspace returns exit code `11` on quit if "Power Off" button was pressed. As a result Login application performs OS shutdown without ordering front panel - should switch to Plymouth shutdown screen.
- "Power Off" quit panel button now starts OS shutdown sequence.
- Current keyboard layout now displayed in first Dock icon - quite ugly but it remains until I'll find better design solution (window titlebar is not an option for me - it's ugly also).
- Bell sound is played via SoundKit with "event" type, so it can be controlled via "System Sounds" application/stream in Mixer.
- Improved application launching and status tracking:
	- launching appicon now reused as normal application icon;
	- if application failed to start launching appicon removed from screen;
	- application that started from FileViewer and ebnormally terminated (segfault, killed with signal) removed from Processes panel;
	- on quit do not try to terminate application if it cannot be connected (just remove from list of known applications).
- Copy operation speed improved. It's 4 times faster now.
- Appicon of runing application can be dragged out of the Dock. It automatically placed in the Icon Yard after mouse up.

### Preferences

- "Login Preferences" module was implemented:
	- implementation completed for "Login Hook", "Logout Hook", "Restore Last Logged In User Name", "Display Host Name".
	- "Display Host Name", "Restore Last Logged In User Name", screen saver, and custom UI and saver preferences can be changed by administrator (user that is member of `wheel` group).
- "Sound Preferences" now display configured "System Beep" with selection of sound in list at first module loading.
- "Password Preferences" module was implemented. Now I need to find out how to change PAM settings to change password as user without SUID bit set (as `passwd` command works).

## Frameworks

### DesktopKit

- Implemented `NXTOpenPanel : NXTSavePanel` and `NXTSavePanel : NSSavePanel`. 
  Differences to NSOpenPanel and NSSavePanel:
	- No icons in browser.
	- Keyboard focus always stays in textfield but Up/Down/Left/Right arrow keys browsing still available (Left/Right only if texfield is empty).
	- Improved performance of scrolling through the list on long Down/Up key press.
	- Selecting directory with keyboard reuires Enter key pres to load directory contents.
	- Unified with File Viewer sorting and displaying hidden files (configurable through "Expert Preferences" "Sort By" and "Show Hidden Files" options).
	- Panels save/restore its position and size;
	- Escape key press pastes current path into textfield - default completion shortcut (also used in Workspace's Finder).
- NXAlertPanel fixed setting size for multi-line messages.

### SoundKit

- implemented play of sound bytes via the SNDPlayStream;
- SNDPlayStream and SNDRecord stream now have ability to pause/resume;