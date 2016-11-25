Intro
=====
    
    This a set of patches to make WindowMaker's look and feel closer to NeXT.
    Patches was created against latest official release of WindowMaker - 0.95.7.
    All patches already applied to the Applications/Workspace/WindowMaker tree.
    
    This file was created as a reminder for me what was changed and why.
    
Patch files naming convention
=============================

    All patches are named with the following format:
    <WindowMaker tree subdir>_<file name>.patch

Patches
=======

General
-------

src/GNUstep.h, src/WindowMaker.h:

    Synchronize NS*WindowLevel with GNUstep's (defined in AppKit/NSWindow.h)

src/main.c:

    - Make real_main() globaly visible function to call from Workspace GCD
      thread.
    - Disable main()
    - execInitScript(): search init script (autostart) in "~/Library/WindowMaker"
    - inotifyWatchConfig(): watch the "~/Library/Preferences/.WindowMaker" for
      configuration changes.
    - Disable command line options processing.
    - Return from real_main before calling EventLoop() - EventLoop() called
      from Workspace main().
    
Configuration
-------------

src/dialog.c:

    Path to history file changed from "/WindowMaker/History" to
    "/.AppInfo/WindowMaker/History". This path used to store running commands
    in "Run" panel.

src/wconfig.h:

    - Set defaults dir to "Preferences/.WindowMaker"
    - Set icon path list
    - Set default fonts to Helevetica family
    - Set DOCK_EXTRA_SPACE to 3
    - Set DOCK_DETTACH_THRESHOLD to 2 (multiple of icon size)

WINGs/userdefaults.c: 

    "/Defaults" -> "/Preferences/.WindowMaker"

src/icon.c:

    - Path to icon cache: 
      "/Library/WindowMaker/CachedPixmaps" -> "/WindowMaker/CachedPixmaps"
      
WINGs/wcolorpanel.c:

    "/Library/Colors/" -> "/WindowMaker/Colors/"

WindowMaker and Workspace interconnection
-----------------------------------------

src/event.c:

    Call Workspace function (XWApplicationDidCloseWindow) when X11 application
    closed its window.
    Notify (call XWUpdateScreenInfo) Workspace about receiving
    XRRUpdateConfiguration X11 notification (XRandR).

src/application.c

    Call Workspace functions on new window openning
    (XWApplicationDidAddWindow), application creation
    (XWApplicationDidCreate), application closing (XWApplicationDidDestroy).

Look and feel
-------------

src/screen.h:

    Define new element in WScreen structure:
        struct RImage *miniwindow_tile;
    This element holds different from appicon (Yard, Dock ) image for miniwindow.
    
src/defaults.c:

    - Added and implemented setMiniwindowTile() - loads and stores miniwindow
      tile image in scr->miniwindow_tile (added in src/screen.h).
    - Add new defaults key - MiniwindowBack and hardcoded value (solid, gray).
    
src/framewin.c:

    Draw highlighted title button image instead of pushed in. This is the
    exact look & feel of OPENSTEP title buttons.

src/icon.c:

    - Use scr->miniwindow_tile instead of scr->icon_tile
    - Do not draw miniwindow title in x-coordinate less then 2 to prevent
      drawing over tile border.

src/window.c:

    - Set wwin->defined_user_flags.shared_appicon = 0 for GNUstep
      applications.
    - Fix moving down on height of title bar and right on border width (1
      pixel) for windows which were already mapped before Workspace (and
      WindowMaker) started.
    
