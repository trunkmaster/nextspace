# NEXTSPACE
-------------------------------------------------------------------------------

NEXTSPACE is desktop environment that brings [NeXTSTEP](https://en.wikipedia.org/wiki/NeXTSTEP) look and feel to Linux. I try to keep the user experience as close as possible to the original NeXT's OS.

![NEXTSPACE example](https://github.com/trunkmaster/nextspace/blob/master/Documentation/NEXTSPACE_Screenshot.png)

## Why am I doing this?
1. I like look, feel and design principles of NeXTstep.
2. I think GNUstep project (http://www.gnustep.org) needs reference implementation of user (not developer) oriented desktop environment.
3. As main developer of ProjectCenter (IDE for GNUstep) I need desktop environment where ProjectCenter can be developed, tested and integrated with.
4. Maybe some day it will be an alternative to GNOME/KDE/etc that interesting for developers and comfortable (fast, easy to use, feature-rich) for end users.
Unlike other 'real' and 'serious' projects I've not defined target audience for NEXTSPACE, I intentionally left outside modern UI design trends (fancy animations, shadows, gray lines, flat controls, acid colours). I like this accurate, clear, grayish, boring UI that just works...

## What NEXTSPACE is?
####Core technologies for development of NEXTSPACE:
* CentOS Linux 7 and its technologies (systemd, UDisks2, Xorg, etc.): stable, well supported enterprise level OS.
* Compiler: Clang 3.8.1
* Objective-C runtime: libobjc2 by Devid Chisnall (https://github.com/gnustep/libobjc2).
* Multithreading: libdispatch by Apple (https://github.com/apple/swift-corelibs-libdispatch).
* GNUstep libraries: http://www.gnustep.org this is where I started from. Additional functionality and fixes will go upstream when will be ready.
* WindowMaker: great window manager. All changes I've packaged as a patches which can be pushed to upstream project.
####Frameworks:
* NXAppKit: GUI classess that can be usefull in multiple applications (for example: ClockView, ProgressBar and ProgressPie).
* NXSystem: system-specific classes goes here (UDisks, UPower, D-BUS, XRandR, XKB, etc.).
* NXFoundation: non-graphical utility classes (custom defaults and bundle management, etc.)
#####Applications:
* Login: simple login panel where you enter your user name and password.
* Workspace: file manager, window manager, process manager, dock.
* Preferences: settings for locale, fonts, displays (size, arrangment), keyboard, mouse, sound, network, power management.
* Terminal: terminal with Linux console emulation.
* TextEdit: simple text editor that supports RTF and RTFD.
* Review: image viewer.
Everything else is optional and will be developed upon completion listed above.

## Status of implementaion
Login - 90%
Workspace - 70% (finish WindowMaker integration, implement icon and list views, Finder, fix stability issues)
Terminal - 95% (implement activity control, apply colours with drag and drop into terminal window)
TextEdit - as is.

## I will not plan to do
* Porting to other Linux distributions and operating systems. However, NEXTSPACE was designed to be portable.
* WindowMaker only fork (Workspace includes WindowMaker though).
* GNOME, KDE rival in terms of visual effects.
* MacOS X like implementation in terms of design. There is another good place for this -- Étoilé (http://etoileos.com).
