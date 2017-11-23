# NEXTSPACE

NEXTSPACE is desktop environment that brings [NeXTSTEP](https://en.wikipedia.org/wiki/NeXTSTEP) look and feel to Linux. I try to keep the user experience as close as possible to the original NeXT's OS. It is developed with ["OpenStep User Interface Guidelines"](http://www.gnustep.org/resources/documentation/OpenStepUserInterfaceGuidelines.pdf) in mind.
> If you've noticed or ever bothered with naming convention all of these "NeXTSTEP, NextStep", here is [explanation](https://github.com/trunkmaster/nextspace/blob/master/Documentation/OpenStep%20Confusion.md).

![NEXTSPACE example](https://github.com/trunkmaster/nextspace/blob/master/Documentation/NEXTSPACE_Screenshot.png)

## Why am I doing this?
1. I like look, feel and design principles of NeXTSTEP.
2. I think [GNUstep](http://www.gnustep.org) needs reference implementation of user oriented desktop environment.
3. As main developer of [ProjectCenter](http://www.gnustep.org/experience/ProjectCenter.html) (IDE for GNUstep) I need desktop environment where ProjectCenter can be developed, tested and integrated with.
4. Maybe some day it will become interesting environment for developers and comfortable (fast, easy to use, feature-rich) for users.

Unlike other 'real' and 'serious' projects I've not defined target audience for NEXTSPACE. I intentionally left aside modern UI design trends (fancy animations, shadows, gray blurry lines, flat controls, acid colours, transparency). I like this accurate, clear, grayish, boring UI that just not hinder to get my job done...

## What NEXTSPACE is?
#### Core technologies it is based on:
* [CentOS Linux 7](https://www.centos.org) and its technologies (systemd, UDisks2, Xorg, etc.): stable, well supported enterprise level OS.
* Compiler: [Clang](http://www.llvm.org/) 3.8.1
* Objective-C runtime: [libobjc2](https://github.com/gnustep/libobjc2) by David Chisnall .
* Multithreading: [libdispatch](https://github.com/apple/swift-corelibs-libdispatch) by Apple.
* [OpenStep](https://en.wikipedia.org/wiki/OpenStep) implementation: [GNUstep](http://www.gnustep.org). This is where I started from back in 2001. Additional functionality and fixes will go upstream when it will be ready.
* [WindowMaker](https://windowmaker.org/): great window manager. It is still alive and in active development. All changes I'm packaging as a set of patches (to the original 0.95.7 version) which can be pushed to upstream project later.
#### Frameworks:
* NXAppKit: GUI classess that can be usefull in multiple applications (for example: ClockView, ProgressBar and ProgressPie).
* NXSystem: system-specific classes goes here (UDisks, UPower, D-BUS, XRandR, XKB, etc.).
* NXFoundation: non-graphical utility classes (custom defaults and bundle management, etc.)

'NX' prefix is a tribute to the NeXTstep classes back in early 90th and has no connection to original NeXT's API.
#### Applications:
* Login: simple login panel where you enter your user name and password.
* Workspace: file manager, window manager, process manager, dock, inspectors, finder, console messages and preferences for mentioned these parts.
* Preferences: settings for locale, fonts, displays (size, arrangment), keyboard, mouse, sound, network, power management. It is designed to manage settings related to: GNUstep (NSGlobalDomain), WindowMaker (~/Library/Prefrences/.NextSpace/WindowMaker), Xorg (keyboard, mouse, displays), CentOS Linux (sound, networking, power).
* Terminal: terminal with Linux console emulation. I've started with version created by Alexander Malmberg and make numerous fixes and enhancements. Original application can found at [GNUstep Application Project](http://www.nongnu.org/gap/terminal/index.html) site.
* TextEdit: simple text editor that supports RTF and RTFD. It is simple application from NeXT Developer demos.
* Review: image viewer. Nothing interesting yet. Maybe replaced by some other image and document (PDF, PostScript, etc.) viewing application in future.
Everything else is optional and will be developed upon completion of core applications listed above. Among them:
* TimeMon: system load monitoring. Version from GNustep Application Project.
* Weather: Shows weather conditions from Yahoo! weather site. Proof of concept (no preferences, no forecast, shows weather for Kyiv, Ukraine).

## Status of implementaion
* Login - 90%
* Workspace - 70% (finish WindowMaker integration, implement icon and list views, Finder, fix stability issues)
* Terminal - 95% (implement activity control, apply colours with drag and drop into terminal window)
* TextEdit - as is.
* Review - early development.

## I will not plan to do
* Porting to other Linux distributions and operating systems for now. I want fast, accurate and stable version for CentOS 7 at last. However, NEXTSPACE was designed to be portable and this point maybe changed in future.
* WindowMaker only fork (Workspace includes WindowMaker though).
* GNOME, KDE, MacOS rival in terms of visual effects, modern design principles, look and feel.
* MacOS X like desktop paradigm. There is another good place for this -- [Étoilé](http://etoileos.com).
