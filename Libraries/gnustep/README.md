# Intro
=======
  This a set of patches to fix/enhance GNUstep libraries.
  After release 1.0 of NEXTSPACE I plan to discuss with GNUstep developers
  inlcuding these chages into upstream code repos.
  Patches was created against the following GNUstep libraries:
  - gnustep-base:	1.24.8
  - gnustep-gui:	0.24.1
  - gnustep-back:	0.24.1
    
  This file was created as a reminder for me what was changed and why.
  After reaching verion 1.0 of NEXTSPACE I'll plan to send these patches
  upstream.

# Compiling RPM package
=======================

  To build GNUstep libraries in one RPM the following patches need to be applied 
  (compiler and linker paths releated changes):
    * gnustep-back-art_GNUmakefile.preamble.patch
    * gnustep-back-gsc_GNUmakefile.preamble.patch
    * gnustep-gui-Model_GNUmakefile.patch

# Backported changes from gnustep-base-1.24.9
=============================================

  * gnustep-base-GSConfig.h.in.patch
  * gnustep-base-Languages_Korean.patch

# Autolaunching applications
============================

  Workspace needs ability to tell applications which was automatically
  launched after user logon and first start of Workspace. Next application
  should understand it and treat such case specifically (do not show app
  menu, do some other specific things). On NeXTSTEP it was implemented by
  adding to app's arguments domain (reached via NSUserDefaults)
  NXAutoLaunch=YES. The patch described below is aimed to make start such
  applications smooth - without focus flickering from Workspace menu to
  autolaunched application's menu - but displaying appicon and its contents
  (for example, Preferences appicon with time and date view).

### gnustep-back-x11_XGServerWindow.m.patch

  @@ -2936,13 +2936,38 @@
  Display application icon if NXAutoLaunch argument was specified. Created
  to fix wierd behaviour of application in case of start without menu and
  following app activation. Create app without menu needed for autostarted
  (hidden on start) apps. Without this patch apps need to hide itself in
  applicationWillFinishLaunching:. Even though application menu first shows
  and after it hides. It looks like flickering focus on Workspace menu.
   
### gnustep-gui-NSApplication.m.patch

  Remove application arguments subdomain after application launch.

### gnustep-gui-NSMenu.m.patch

  Display menus only if NXAutoLaunch option was not specified.

# NS*WindowLevel
================

### gnustep-gui-NSWindow.h.patch
  Changed values in enum to separate menus and floating panels.
    
### gnustep-back-x11_XGServerWindow.m.patch
  * @@ -3397,7 +3422,6 @@, @@ -3411,6 +3435,11 @@
    Separate menus from floating panels. Set window special property for
    floating panels.

# Miniwnidow style
==================

### gnustep-gui-NSWindow.m.patch
  * @@ -479,7 +479,7 @@
    Use "common_MiniWindowTile.tiff" as a tile image for miniwindows.
    
  * @@ -512,8 +512,8 @@
    Justify horizontal postion and width of miniwindow title text. Now
    titletext doean't overlap miniwindow border.

  * @@ -603,7 +603,7 @@
    Set miniwindow title font pixel size to 9 instead of 8.

# Mouse cursors
===============

### gnustep-back-x11_XGServerWindow.m.patch
  * @@ -4301,25 +4330,31 @@
    Change names of cursors to conform new design paradigm.
    
  * @@ -4398,7 +4433,7 @@
    Fixed typo in "BGRA" name format.


# Miniatirize Window and Hide application
=========================================
  
  This task was more complex than I expect partly because of some unused or
  weird code. Based on information from back/Documentation/Back/Standards.txt, GNUstep Back and 
  WindowMaker source code I concluded that WindowMaker and application can interconnect 
  by several methods:
  1. Application set to owned window some `attributes`. Attributes can be set with some 
     `property` name known to both: window manager and application. Window manager then 
     checks for property value with XGetWindowProperty() Xlib function call.
     Property `\_GNUSTEP\_WM\_ATTR` created to assign to window extra attributes not
     existed in Xlib header files.
  2. Sending messages with XSendEevent() with event type `XClientMessageEvent` structure. 
     `message_type` atom is set to known protocol or property name and `data` union field 
     is set to some values known to both application (window) and window manager.
  
  Let's take a look at "WindowMaker Protocols and Client Messages" section.
  - `_GNUSTEP_WM_MINIATURIZE_WINDOW` - tells to window manager that window, accepts 
    requests to Miniaturize window with client message.
  - `_GNUSTEP_TITLEBAR_STATE` - tells to window manager that window, accepts 
    requests to get or set titlebar appearnce of window.
  - `_GNUSTEP_WM_ATTR` - property for setting various attributes about the window.
    One of the fields in GNUstepWMAttributes structure is `extra_flags`. It takes OR'ed
    values of window attributes (style, level, pixmaps, etc). And now something unexpected:
    `WMFHideOtherApplications` and `WMFHideApplication`! What? Are they protocols?
    Are they message types? (rememeber this is value of field in structure called 
    GNUstepWM*Attributes*). What these attributes should tell to window manager? Some variants:
    _WMFHideOtherApplications_
    - window can hide other aplications;
    - window can be hidden while somebody hides applications;
    - window want to send request to hide othe applications to window manager.
    _WMFHideApplication_
    - window accept requests to hide application - why it's not protocol (property) and 
      not called \_GNUSTEP\_WM\_HIDE\_APP like protocol property for Miniaturize action?;
  
  I've failed to find answer for these questions and decided to:
  - create new protocol property `_GNUSTEP_WM_HIDE_APP` - tells to window manager that 
    window, accepts requests to Hide application with client message.
  - create new protocol property `_GNUSTEP_WM_HIDE_OTHERS` - tells to clients that window
    manager accepts message to hide all windows of applications except caller application.
    
  To sum up, here are some interconnection agreement statements.
  AppKit (GNUstep) application must support:
  - `_GNUSTEP_TITLEBAR_STATE` - WM can manage titlebar state app window;
  - `_GNUSTEP_WM_ATTR` - WM can manage some specific atrributes of AppKit app;
  - `_GNUSTEP_WM_MINIATURIZE_WINDOW` - protocol, WM can request app window to iconify itself;
  - `_GNUSTEP_WM_HIDE_APP` - protocol, WM can request app window to hide application windows.

  Window manager must support:
  - `_GNUSTEP_WM_HIDE_OTHERS` - application can request to hide windows of other applications.
  - `_GNUSTEP_FRAME_OFFSETS` - application can get information to calculate window geometry.
  
### gnustep-back-x11_XGGeneric.h.patch

