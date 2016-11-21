Intro
=====
    
    This a set of patches to fix/enhance GNUstep libraries.
    After release 1.0 of NEXTSPACE I plan to discuss with GNUstep developers
    inlcuding these chages into upstream code repos.
    Patches was created against the following GNUstep libraries:
    - gnustep-base:	1.24.8
    - gnustep-gui:	0.24.1
    - gnustep-back:	0.24.1
    
    This file was created as a reminder for me what was changed and why.

Compiling RPM package
=====================

    To build GNUstep libraries in one RPM these changes dealing with compiler
    and linker paths:
    * gnustep-back-art_GNUmakefile.preamble.patch
    * gnustep-back-gsc_GNUmakefile.preamble.patch
    * gnustep-gui-Model_GNUmakefile.patch

Backported changes from gnustep-base-1.24.9
===========================================

    * gnustep-base-GSConfig.h.in.patch
    * gnustep-base-Languages_Korean.patch

Autolaunching applications
==========================

    Workspace needs ability to tell applications which was automatically
    launched after user logon and first start of Workspace. Next application
    should understand it and treat such case specififcally (do not show app
    menu, do some other specific things). On NeXTSTEP it was implemented by
    adding to app's arguments domain (reached via NSUserDefaults)
    NXAutoLaunch=YES. The patch described below is aimed to make start such
    applications smooth - without focus flickering from Workspace menu to
    autolaunched application's menu - but displaying appicon and its contents
    (for example, Preferences appicon with time and date view).

    * gnustep-back-x11_XGServerWindow.m.patch
      * @@ -2936,13 +2936,38 @@
        Display application icon if NXAutoLaunch argument was specified. Created
        to fix wierd behaviour of application in case of start without menu and
        following app activation. Create app without menu needed for autostarted
        (hidden on start) apps. Without this patch apps need to hide itself in
        applicationWillFinishLaunching:. Even though application menu first shows
        and after it hides. It looks like flickering focus on Workspace menu.
   
gnustep-gui-NSApplication.m.patch
---------------------------------

    Remove application arguments subdomain after application launch.

gnustep-gui-NSMenu.m.patch
--------------------------

    Display menus only if NXAutoLaunch option was not specified.

NS*WindowLevel
==============

    * gnustep-gui-NSWindow.h.patch
      Changed values in enum to separate menus and floating panels.
    
gnustep-back-x11_XGServerWindow.m.patch
---------------------------------------

    * @@ -3397,7 +3422,6 @@, @@ -3411,6 +3435,11 @@
      Separate menus from floating panels. Set window special property for
      floating panels.

Miniwnidow style
==================

    * gnustep-gui-NSWindow.m.patch
      * @@ -479,7 +479,7 @@
        Use "common_MiniWindowTile.tiff" as a tile image for miniwindows.
    
    * @@ -512,8 +512,8 @@
      Justify horizontal postion and width of miniwindow title text. Now
      titletext doean't overlap miniwindow border.

    * @@ -603,7 +603,7 @@
      Set miniwindow title font pixel size to 9 instead of 8.

Temporary, in test, postponed
=============================

    gnustep-back-art_ReadRect.m.patch
