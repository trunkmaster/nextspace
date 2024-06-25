# NEXTSPACE 0.95 changes

## General

- Fixes to package installation of Xorg (Xavier Brochard <xavier@alternatif.org>)
- SELinux policies support: adds policies, changes to the spec and to the install script (Frederico Munoz <fsmunoz@gmail.com>)
- ProjectCenter and GORM changes to icons and info panels (Andres Morales <armm77@icloud.com>)
- Use internal version of GNUstep Back with modified sources: see "back-art" section below.
- Base libraries versions bump for Debian/Ubuntu and Fedora:
	- GNUstep Make 2.9.2
	- GNUstep Base 1.30.0
	- GNUstep GUI 0.31.0
	- libobjc2 2.2.1
	- libdispatch 5.9.2
	- Core Foundation 5.9.2
- /etc/profile.d/nextspace.sh: fixes to development and user environment settings
- Fontconfig configuration was made systemwide (link in /etc/fonts/conf.d).
- Packaging/Sources scripts now works for Debian 12 and Ubuntu 22.04 as well as Fedora 39.

## Applications

### Workspace

- Adedded and implemented "Open in Workspace" service (OnFlApp <onflapp@gmail.com>)
- "Hide" menu item: treat Workspace application specially - set focus to main menu before windows hiding, do not hide main menu, do not change focus to other app after windows hiding.
- Implemented "Hide Others" menu item.
- Implemented Cut/Copy/Paste operations for files and directories.
- Fixes to keyboard layout changes and app icon badge display. Don't show keyboard layout badge on appicon if single keyboard layout was configured.
- Continued fixing of focus problems - it still happens occassionally.
- Don't set focus to GNUstep and Withdrawn (dockapp) windows. GNUstep sets focus by itself, dockapp windows is not intended to be focused by design (fixes focus flickering of Workspace during startup if dockapp is autolaunched).
- Improved applications termination handling.
- "Launching appicons": implementation was moved into WM: made appicons list part of WScreen structure; use wSlideWindow() for flying icon animation for more smooth animation.
- Don't create launching icon if WM name is empty; change WM icon only of supplied path is not empty.
- NSWorkspace delegate functionality completely implemented and tested.
- Show alert panel for incorrectly created application wrappers.
- Implemented -extendPowerOffBy: method even though it was neither working on NeXT nor on Apple platforms.
- Track for applications and services installation/removal - update caches, no need to logout/login.

#### Window Manager

Major part of Workspace Window Manager (formerly WindowMaker) was refactored and rewritten.

- WINGs data structures and supporting functions were completely replaced by CoreFoundation counterparts. 
    - WINGs removed - only core components/structures left essential to provide core WM's functionality (title/resize bars, window management, icons, baloons, DnD, menus).
    - CFStrings with UTF-8 encoding now used whenever it's possible and appropriate.
    - Adopted usage of many CoreFoundation data structures (CFArray, CFDictionary, CFData, CFPropertyList...)
- Removed WM's blocking event loop - use CFRunLoop to manage Xlib events, timers, notifications using new CFFileDescriptor implementation. Animations became more smooth and nice looking without freeze or speedup.
- Notifications:
    - Internal WM's notifications processed via CFNotificationCenter.
    - Implemented bridge between AppKit and CoreFoundation notification centers. Bridge converts ObjC<->C user data: Array, Dictionary, String, Number.
    - Notifications between Objective-C and C parts of Workspace were implemented with bridge between NSNotificationCenter and CFNotificationCenter. Internal Window Manager's notifications processed by CFNotificationCenter.
    - External Onjective_C applications could send notifications to WM through NSGlobalNotifcationCenter. Notifications named prefixed with "WMShould..." and should be sent as "GSWorkspaceNotification". Actions could be: Miniaturize, Shade, Hide, Close etc. Notification names are located in "DesktopKit/NXTWorkspace.h".
    - Interconnection between Workspace and WM now possible with CFNotificationCenter and NSNotificationCenter. Potentially it's possible to implement notification handling for any Objective-C application by WM. For example, WM can observe NSApplicationDidFinishNotification to make updates in its data or perform some actions.
    - Notifications were renamed in style of Appkit notifications prefixed by "WM".
- Plenty of functions were renamed into the form of Objective-C world with static functions prefixed by "_" symbol.
- Defaults (stored in ~/Library/Preferences/.NextSpace in XML format) contains only settings which differ from default values.
- Implemented handling of _NET_REQUEST_FRAME_EXTENTS message - works better with GNUstep Backend code and logic.
- Initial configuration was replaced from autotools to CMake as more clean and simple method for 'libwraster', 'Workspace/WM'.
- A lot of Workspace+WM.[hm] functions were moved into files located in Workspace/WM.
- Workspace/WM defaults handling now self-contained - no need to have files inside ~/Library/Preferences - files are created and removed if needed.
- Create application menu for non-GNUstep apps:
    - State of menus and submenus are saved and restored between app restarts.
    - Menu also available with right-click on desktop while application is active.
    - Menus can't be moved outside of the screen at top.
- Window's menu (right-click on titlebar) stripped down to window options.
- Set root window background pixmap with _ROOTPMAP_ID property name to be catched by composer.

### Terminal

- Added "Paste Selection" menu item (OnFlApp <onflapp@gmail.com>).
- Added support for setting title via xterm escape sequence (OnFlApp <onflapp@gmail.com>).
- Use shell configured in preferences if "Default Shell" option was set. Open new window with shell and send command to that shell for "New Window" and "Default Shell" case.
- On "Paste" operation insert space before pasting text only if character before cursor is not space.
- Adjust default terminal colors to more visible on light background.
- Fixed window size representation to be on par with WM.
- Dynamically enlarge scrollback buffer on new incoming data (output to terminal screen) up to the maximum lines has been set in preferences.
- Improved running processes tracking (/proc info is used).
- Display currently running program in titlebar.
- Implemented miniaturized window icon animation when window contents is changing. Animation represents real dynamics of lines shift in terminal window.
- Implemented timed app icon animation in Info panel.
- Added "Activity Monitor" preferences section. If activity monitor was diabled - icon animation is disabled too.

### Preferences

- Minor fixes in Font and Mouse preferences.
- Added Services section.
- Show window if application was not autostarted, hide it otherwise.
- Fixed subsections placement for Keyboard Preferences.

## Libraries and frameworks

### Core Foundation

- New framework as dependency of Workspace Window Manager.
- CFFileDescriptor - doesn't exists in opensource version of CoreFoundation. Thanks to http://www.puredarwin.org project - I've grabbed and enhanced it to work on my current setup. In Workspace/WM CFFileDescriptor is used to track Xlib and Linux inotify events.
- CFNotificationCenter - missed from Apple's sources except header file - I've used Stuart Crook implementation found on GitHub, fixed, tested and used for notifications delivery inside WM and between WM and Workspace. Works good.

### back-art

- Use forked and simplified GNUstep Back ART backend with enhancements. The reason is: ART backend works almost perfectly for NEXTSPACE and most of changes I've made were to X11 part of backend which are quite useless for Cairo-X11 backend. I hope it's temporary solution for Xorg - next big step would be a switch to Wayland/Cairo.
- Implemented DnD support of filenames. At least it works between Workspace and WM (DnD of files over docked and not running apps).
- Added support for WM-based main application menus: set window type to _NET_WM_WINDOW_TYPE_TOOLBAR.
