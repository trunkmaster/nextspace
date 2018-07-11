* Intro
    
  This a set of patches to make WindowMaker's look and feel closer to NeXT.
  Patches was created against latest official release of WindowMaker - 0.95.7.
  All patches already applied to the Applications/Workspace/WindowMaker tree.
  
  This file was created as a reminder for me what was changed and why.

  All changes are guarded by `#ifdef NEXTSPACE ... #endif`.
    
  Patches are named with the following format:
  <WindowMaker tree subdir>_<file name>.patch
  
  | Filename | Location | Description | Tags |
  | -------- |--------- | ----------- | ---- |
  

* WINGs/userdefaults.c
  @@ -40,7 +40,11 @@			Configuration, Integration
  Change configuration directory to "~/Library/Preferences/.WindowMaker".

* WINGs/wcolorpanel.c
  @@ -397,7 +397,11 @@			Configuration
  Save colors of WINGs color panel to "~/Library/WindowMaker/Colors".

* src/GNUstep.h
  @@ -49,20 +49,20 @@			Intergation

  Synchronize NS*WindowLevel with GNUstep's (defined in AppKit/NSWindow.h)

* src/WindowMaker.h
  @@ -56,7 +56,7 @@			Integration
  [[https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/WindowMaker.h#L56-L63][src/WindowMaker.h]]
  Fix WMSubmenuLevel value.

  @@ -92,14 +92,16 @@			Look and feel
  New maximize and unmaximize images were added for Alternate-Click on left titlebar button.

  @@ -113,6 +115,10 @@			Mouse and cursors
  New values for oneway mouse cursors (up, down, left, right) were added:
  WCUR_UPRESIZE, WCUR_DOWNRESIZE, WCUR_LEFTRESIZE, WCUR_RIGHTRESIZE.

* src/actions.c
  @@ -1133,7 +1133,6 @@			Dock and IconYard
  Don't mark icon as mapped. It will be done by Workspace code.

  @@ -1211,9 +1210,15 @@		Dock and IconYard
  Show appicon only if Icon Yard is mapped.

* src/appicon.c
  @@ -54,6 +54,9 @@			Dock and IconYard
  @@ -242,7 +245,12 @@			Dock and IconYard
  Show appicon only if Icon Yard is mapped.

  @@ -1048,7 +1056,13 @@		Look and feel
  Call DoKaboom() through dispatch_async() to prevent effect from blocking
  Workspace user interaction.

* src/application.c
  @@ -100,6 +103,13 @@			Integration
  @@ -140,6 +150,13 @@			Integration
  @@ -166,6 +183,15 @@			Integration
  Call Workspace functions on new window openning
  (XWApplicationDidAddWindow), application creation
  (XWApplicationDidCreate), application closing (XWApplicationDidDestroy).

* src/def_pixmaps.h
  @@ -63,26 +62,42 @@			Look and feel
  - Kill operation image of close titlebar button was modified.
  - Added images for Maximize and Unmaximize operations.

* src/defaults.c:
  @@ -553,6 +556,10 @@			Look and feel
  - Add new defaults key - MiniwindowBack and hardcoded value (solid, gray).

  @@ -818,6 +825,14 @@			Mouse and cursors
  - New defaults were added for oneway mouse cursors: UpResizeCursor, 
    DownResizeCursor, LeftResizeCursors, RightResizeCursors.
  - Set default names of cursors for oneway cursors.

  @@ -2482,6 +2500,26 @@		Mouse and cursor
  Process new type mouse cursors - "library". These types of cursors
  are loaded with libXcursor Xorg extention. Values are treated as
  cursor file names inside current theme.

  @@ -2681,6 +2719,56 @@		Look and feel
  Implemented setMiniwindowTile() - loads and stores miniwindow
  tile image in scr->miniwindow_tile (added in src/screen.h).

* src/dialog.c:
  @@ -177,7 +177,11 @@			Configuration
  Path to history file changed from "/WindowMaker/History" to
  "/.AppInfo/WindowMaker/History". This path used to store running commands
  in "Run" panel.

* src/dock.c
  @@ -854,7 +858,9 @@			Integration
  Do not map appicon upon creation.

  @@ -1959,9 +1965,10 @@		Integration
  Do not map icons during restore state. It will be done by Workspace code.

  @@ -2237,6 +2244,10 @@		Integration
  @@ -2256,6 +2267,10 @@		Integration
  @@ -2455,6 +2470,9 @@			Integration
  Notify Workspace about Dock content changes.

* src/event.c:
  @@ -90,6 +93,10 @@			Look and feel
  New functions for button and key release were added.

  @@ -209,6 +216,11 @@			Look and feel
  Handle KeyRelease event.

  @@ -237,6 +249,11 @@			Look and feel
  Handle ButtonRelease event.

  @@ -580,9 +597,15 @@			Integration
  Notify (call XWUpdateScreenInfo) Workspace about receiving
  XRRUpdateConfiguration X11 notification (XRandR).

  @@ -670,6 +693,9 @@			Integration
  Call Workspace function (XWApplicationDidCloseWindow) when X11 application
  closed its window.

  @@ -803,17 +829,48 @@			Look and feel, Integration
  - Restore left titlebar button image.
  - Right-click on desktop will show application menu for GNUstep
    application and Workspace menu for X11 application.

  @@ -839,15 +896,12 @@			Look and feel, Focus
  Cleanup in window content click. When modifier pressed mouse click will not 
  pass to application.

  @@ -873,6 +927,25 @@			Look and feel, Integration
  handleButtonRelease() implementation.

  @@ -1389,13 +1460,32 @@		Look and feel, Window managemnt
  Update titlebar button images on modifier press.

  @@ -1866,11 +1956,56 @@
  - handleKeyRelease() implementation;
  - window movement while titlebar grabbed.

* src/framewin.c:
  @@ -1317,9 +1317,14 @@ 		Look and feel
  @@ -1363,6 +1368,9 @@			Look and feel
  Draw highlighted title button image instead of pushed in. This is the
  exact look & feel of OPENSTEP title buttons.

* src/icon.c:
  @@ -51,7 +51,12 @@
  Path to icon cache changed to "~/Library/WindowMaker/CachedPixmaps".

  @@ -234,6 +239,7 @@			Look and feel
  @@ -313,8 +325,10 @@			Look and feel
  Do not draw miniwindow title, new miniwindow tile image will used instead.

  @@ -254,7 +261,12 @@			Look and feel
  Use new miniwindow tile image (scr->miniwindow_tile) instead of scr->icon_tile.

  @@ -508,10 +522,14 @@			Look and feel
  Try to save cached application icon as TIFF instead of XPM in 
  "~/Library/WindowMaker/ChachedPixmaps".

  @@ -781,7 +799,9 @@			Look and feel
  Do not draw miniwindow title in x-coordinate less then 2 to prevent
  drawing over tile border.

* src/main.c:
  @@ -105,7 +105,7 @@			Integration
  Make real_main() globaly visible function to call from Workspace GCD
  thread.

  @@ -492,7 +492,11 @@			Configuration
  Use GNUSTEP_USER_ROOT (~/Library) instead of ~/GNUstep.
  Watch the "~/Library/Preferences/.WindowMaker" for configuration changes. 

  @@ -514,7 +518,11 @@			Configuration
  Search init script (autostart) in "~/Library/WindowMaker"

  @@ -546,6 +554,7 @@			Integration
  Do not compile main().

  @@ -617,6 +627,7 @@			Integration
  Skip some extra initializations, commandline options handling.

  @@ -808,6 +820,10 @@			Integration
  Return from real_main before calling EventLoop() - EventLoop() called
  from Workspace main().

* src/moveres.c:	Mouse and cursors
  @@ -1996,8 +1996,8 @@
  ?Removed abs()?

  @@ -2040,6 +2040,186 @@		Look and feel, Mouse and cursors
  @@ -2068,6 +2248,11 @@		Look and feel, Mouse and cursors
  New mouse cursor behavior when reached minimum/maximum window size: 
   - mouse cursors stops moving;
   - mouse cursor changes to image hinting to user appropriate resize 
     direction.

  @@ -2211,6 +2400,10 @@
  Do not redraw resize frame if mouse location hasn't changed despite the
  incoming events from X11.

* src/placement.c
  @@ -66,7 +66,11 @@			Look and feel
  Take into account Icon Yard visibility on icon postion calculation.

* src/screen.c:
  @@ -268,6 +268,16 @@
  Use Maximize and Unmaximize titlebar button pixmaps.

  @@ -787,6 +797,9 @@
  Initialize WScreen flag icon_yard_mapped at startup.

* src/screen.h:		Look and feel
  @@ -250,6 +250,9 @@
  Define new element in WScreen structure: `struct RImage *miniwindow_tile`;
  This element holds different from appicon (Yard, Dock ) image for miniwindow.

  @@ -310,6 +313,10 @@
  New flags: `icon_yard_mapped` and `modifier_pressed`.
    
* src/superfluous.c:
  @@ -152,7 +152,7 @@
  Make ghost icon tint more opaque.

* src/wconfig.h:	Configuration
  - Set defaults dir to "Preferences/.WindowMaker"
  - Set icon path list
  - Set default fonts to Helevetica family
  - Set DOCK_EXTRA_SPACE to 3
  - Set DOCK_DETTACH_THRESHOLD to 2 (multiple of icon size)

* src/window.c
  @@ -755,9 +755,10 @@			Configuration
  Set wwin->defined_user_flags.shared_appicon = 0 for GNUstep applications.

  @@ -1161,6 +1162,15 @@		Window management
  Fix moving down on height of title bar and right on border width (1
  pixel) for windows which were already mapped before Workspace (and
  WindowMaker) started.

  @@ -1574,7 +1584,8 @@			Focus
  Switch focus to GNUstep app menu (that is in skip_window_list).
  Fixes the bug: menu-only application loses focus after right-click on appicon.

  @@ -2075,6 +2086,14 @@		Window management
  Fix for VirtualBox VM window.

  @@ -2212,7 +2231,16 @@		Look and feel, Window management
  @@ -2266,7 +2294,12 @@		Look and feel, Window management
  Titlebar button pixmaps changes handling if modifier key pressed.

  @@ -2567,6 +2600,12 @@		Keyboard
  Grab Super_L and Super_R as modifiers. // FIXME

  @@ -2802,6 +2841,7 @@			Window management, Focus
  @@ -2818,6 +2858,7 @@			Window management, Focus
  @@ -2971,6 +3012,7 @@			Window management, Focus
  @@ -2982,6 +3024,7 @@			Window management, Focus
  New resize/move concept: do not block focus changing code until resize/move
  finished.

  @@ -3100,6 +3143,15 @@		Window management
  Maximize/Unmaximize window when modifier+click on miniaturize titlebar button.

* src/workspace.c
  @@ -50,6 +50,9 @@			Look and feel, Integration
  @@ -436,6 +439,9 @@			Look and feel, Integration
  Call XWWorkspaceDidChange() to update current workspace badge in
  Workspace application icon.

* src/xinerama.c
  @@ -306,7 +307,7 @@			Look and feel, Integration
  Include Dock size in `usableArea` calculations only if Dock is visible.

  @@ -315,6 +316,15 @@			Look and feel, Integration
  Include IconYard size in `usableArea` calculations only if IconYard is visible.
    
* WINGs/wcolor.c:
  Make WINGs color of widgets match the GNUstep one.

  @@ -245,7 +245,7 @@			Look and feel
  Control color.

  @@ -283,7 +283,7 @@			Look and feel
  Unfocused main window titlebar color.
