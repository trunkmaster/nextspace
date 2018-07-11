# WindowMaker patches
    
  This a set of patches to make WindowMaker's look and feel closer to NeXT.
  Patches was created against latest official release of WindowMaker - 0.95.7.
  All patches already applied to the Applications/Workspace/WindowMaker tree.
  
  This file was created as a reminder for me what was changed and why.

  All changes are guarded by `#ifdef NEXTSPACE ... #endif`.
    
  Patches are named with the following format:
  `<WindowMaker tree subdir>_<file name>.patch`
  
### WINGs/userdefaults.c

  **[Configuration]** [@@ -40,7 +40,11 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/WINGs/userdefaults.c#L40-L51)
    
  Change configuration directory to "~/Library/Preferences/.WindowMaker".

### WINGs/wcolorpanel.c

  **[Configuration]** [@@ -397,7 +397,11 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/WINGs/wcolorpanel.c#L397-L408)

  Save colors of WINGs color panel to "~/Library/WindowMaker/Colors".

### WINGs/wcolor.c:

  Make WINGs color of widgets match the GNUstep one.

  **[Look and feel]**
  [@@ -245,7 +245,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/WINGs/wcolor.c#L245-L252)
  Control color.

  **[Look and feel]**
  [@@ -283,7 +283,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/WINGs/wcolor.c#L283-L290)
  Unfocused main window titlebar color.

### src/GNUstep.h

  **[Intergation]**
  [@@ -49,20 +49,20 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/GNUstep.h)
  Synchronize NS\*WindowLevel with GNUstep's (defined in AppKit/NSWindow.h)

### src/WindowMaker.h

  **[Intergation]**
  [@@ -56,7 +56,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/WindowMaker.h)
  Fix WMSubmenuLevel value.

  **[Look and feel]**
  [@@ -92,14 +92,16 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/WindowMaker.h)
  New maximize and unmaximize images were added for Alternate-Click on left titlebar button.

  **[Mouse and cursors]**
  [@@ -113,6 +115,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/WindowMaker.h)
  New values for oneway mouse cursors (up, down, left, right) were added: WCUR\_UPRESIZE, WCUR\_DOWNRESIZE, WCUR\_LEFTRESIZE, WCUR\_RIGHTRESIZE.

### src/actions.c
  **[Dock and IconYard]**
  [@@ -1133,7 +1133,6 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/actions.c#L1133-L1139)
  Don't mark icon as mapped. It will be done by Workspace code.

  **[Dock and IconYard]**
  [@@ -1211,9 +1210,15 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/actions.c#L1210-L1225)
  Show appicon only if Icon Yard is mapped.

### src/appicon.c

  **[Dock and IconYard]**
  [@@ -54,6 +54,9 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/appicon.c#L54-L63),
  [@@ -242,7 +245,12 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/appicon.c#L245-L12)
  Show appicon only if Icon Yard is mapped.

  **[Look and feel]**
  [@@ -1048,7 +1056,13 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/appicon.c#L1056-L1069)
  Call DoKaboom() through dispatch_async() to prevent effect from blocking Workspace user interaction.

### src/application.c

  **[Integration]**
  [@@ -100,6 +103,13 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/application.c#L130-L116),
  [@@ -140,6 +150,13 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/.c#L150-L163),
  [@@ -166,6 +183,15 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/.c#L183-L198)
  Call Workspace functions on new window openning (XWApplicationDidAddWindow), application creation (XWApplicationDidCreate), application closing (XWApplicationDidDestroy).

### src/def_pixmaps.h

  **[Look and feel]**
  [@@ -63,26 +62,42 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/def\_pixmaps.h.c#L62-L104)
  - Kill operation image of close titlebar button was modified.
  - Added images for Maximize and Unmaximize operations.

### src/defaults.c:

  **[Look and feel]**
  [@@ -553,6 +556,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/defaults.c#L556-L566)
  Add new defaults key - MiniwindowBack and hardcoded value (solid, gray).

  **[Mouse and cursors]**
  [@@ -818,6 +825,14 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/defaults..c#L825-L839)
  - New defaults were added for oneway mouse cursors: UpResizeCursor, DownResizeCursor, LeftResizeCursors, RightResizeCursors.
  - Set default names of cursors for oneway cursors.

  **[Mouse and cursor]**
  [@@ -2482,6 +2500,26 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/defaults.c#L2500-L2526)
  Process new type mouse cursors - "library". These types of cursors are loaded with libXcursor Xorg extention. Values are treated as cursor file names inside current theme.

  **[Look and feel]**
  [@@ -2681,6 +2719,56 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/defaults.c.c#L2719-L2775)
  Implemented setMiniwindowTile() - loads and stores miniwindow tile image in scr->miniwindow\_tile (added in src/screen.h).

### src/dialog.c:
  
  **[Configuration]**
  [@@ -177,7 +177,11 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/dialog.c#L177-L188)
  Path to history file changed from "/WindowMaker/History" to "/.AppInfo/WindowMaker/History". This path used to store running commands in "Run" panel.

### src/dock.c

  **[Integration]**
  [@@ -854,7 +858,9 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/dock.c#L858-L867)
  Do not map appicon upon creation.

  **[Integration]**
  [@@ -1959,9 +1965,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/dock.c#L1965-L1975)
  Do not map icons during restore state. It will be done by Workspace code.

  **[Integration]**
  [@@ -2237,6 +2244,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/dock.c#L2244-L2254),
  [@@ -2256,6 +2267,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/dock.c#L2267-L2277),
  [@@ -2455,6 +2470,9 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/dock.c#L2470-L2479)
  Notify Workspace about Dock content changes.

### src/event.c:

  **[Look and feel]**
  [@@ -90,6 +93,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/event.c#L93-L103)
  New functions for button and key release were added.

  **[Look and feel]**
  [@@ -209,6 +216,11 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/event.c#L216-L226) 
  Handle KeyRelease event.

  **[Look and feel]**
  [@@ -237,6 +249,11 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/event.c#L249-L260)
  Handle ButtonRelease event.

  **[Integration]**
  [@@ -580,9 +597,15 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/event.c#L597-L613)
  Notify (call XWUpdateScreenInfo) Workspace about receiving XRRUpdateConfiguration X11 notification (XRandR).

  **[Integration]**
  [@@ -670,6 +693,9 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/event.c#L693-L702)
  Call Workspace function (XWApplicationDidCloseWindow) when X11 application closed its window.

  **[Integration]**
  [@@ -803,17 +829,48 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/event.c#L829-L877)
  - Restore left titlebar button image.
  - Right-click on desktop will show application menu for GNUstep
    application and Workspace menu for X11 application.

  **[Focus]**
  [@@ -839,15 +896,12 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/event.c#L896-L908)
  Cleanup in window content click. When modifier pressed mouse click will not pass to application.

  **[Integration]**
  [@@ -873,6 +927,25 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/event.c#L927-L952)
  handleButtonRelease() implementation.

  **[Window managemnt]**
  [@@ -1389,13 +1460,32 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/event.c#L1460-L1492)
  Update titlebar button images on modifier press.

  **[Look and feel]**
  [@@ -1866,11 +1956,56 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/event.c#L1956-L2012)
  - handleKeyRelease() implementation;
  - window movement while titlebar grabbed.

### src/framewin.c:

  **[Look and feel]**
  [@@ -1317,9 +1317,14 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/framewin.c#L1317-L1331),
  [@@ -1363,6 +1368,9 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/framewin.c#L1368-L1377)
  Draw highlighted title button image instead of pushed in. This is the exact look & feel of OPENSTEP title buttons.

### src/icon.c:
  
  **[Configuration]**
  [@@ -51,7 +51,12 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/icon.c#L51-L63)
  Path to icon cache changed to "~/Library/WindowMaker/CachedPixmaps".

  **[Look and feel]**
  [@@ -234,6 +239,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/icon.c#L239-L246), 
  [@@ -313,8 +325,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/icon.c#L325-L335)
  Do not draw miniwindow title, new miniwindow tile image will used instead.

  **[Look and feel]**
  [@@ -254,7 +261,12 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/icon.c#L261-L273)
  Use new miniwindow tile image (scr->miniwindow\_tile) instead of scr->icon\_tile.

  **[Look and feel]**
  [@@ -508,10 +522,14 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/icon.c#L522-L536)
  Try to save cached application icon as TIFF instead of XPM in "~/Library/WindowMaker/ChachedPixmaps".

  **[Look and feel]**
  [@@ -781,7 +799,9 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/icon.c#L799-L808)
  Do not draw miniwindow title in x-coordinate less then 2 to prevent drawing over tile border.

### src/main.c:

  **[Integration]**
  [@@ -105,7 +105,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/main.c#L105-L112)
  Make real_main() globaly visible function to call from Workspace GCD thread.

  **[Configuration]**
  [@@ -492,7 +492,11 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/main.c#L492-L503)
  Use GNUSTEP\_USER\_ROOT (~/Library) instead of ~/GNUstep. Watch the "~/Library/Preferences/.WindowMaker" for configuration changes. 

  **[Configuration]**
  [@@ -514,7 +518,11 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/main.c#L518-L529)
  Search init script (autostart) in "~/Library/WindowMaker"

  **[Integration]**
  [@@ -546,6 +554,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/main.c#L554-L561)
  Do not compile main().

  **[Integration]**
  [@@ -617,6 +627,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/main.c#L627-L634)
  Skip some extra initializations, commandline options handling.

  **[Integration]**
  [@@ -808,6 +820,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/main.c#L820-L830)
  Return from real_main before calling EventLoop() - EventLoop() called from Workspace main().

### src/moveres.c

  [@@ -1996,8 +1996,8 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/moveres.c#L1996-L2004)
  ?Removed abs()? Whay I did this? // FIXME

  **[Mouse and cursors]**
  [@@ -2040,6 +2040,186 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/moveres.c#L2040-L2226),
  [@@ -2068,6 +2248,11 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/moveres.c#L2248-L2259) 
  New mouse cursor behavior when reached minimum/maximum window size: 
   - mouse cursors stops moving;
   - mouse cursor changes to image hinting to user appropriate resize 
     direction.

  **[Look and feel]**
  [@@ -2211,6 +2400,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/moveres.c#L2400-L2410)
  Do not redraw resize frame if mouse location hasn't changed despite the incoming events from X11.

### src/placement.c

  **[Look and feel]**
  [@@ -66,7 +66,11 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/placement.c#L66-L77)
  Take into account Icon Yard visibility on icon postion calculation.

### src/screen.c:

  **[Window management]**
  [@@ -268,6 +268,16 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/screen.c#L268-L284)
  Use Maximize and Unmaximize titlebar button pixmaps.

  **[Look and feel]**
  [@@ -787,6 +797,9 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/screen.c#L797-L806)
  Initialize WScreen flag `icon_yard_mapped` at startup.

### src/screen.h

  **[Look and feel]**
  [@@ -250,6 +250,9 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/screen.h#L250-L259)
  Define new element in WScreen structure: `struct RImage *miniwindow_tile`. This element holds different from appicon (Yard, Dock ) image for miniwindow.

  **[Look and feel]**
  [@@ -310,6 +313,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/screen.h#L313-L323)
  New flags: `icon_yard_mapped` and `modifier_pressed`.
    
### src/superfluous.c:

  **[Look and feel]**
  [@@ -152,7 +152,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/superfluous.c#L152-L159)
  Make ghost icon tint more opaque.

### src/wconfig.h 

  **[Configuration]**
  - Set defaults dir to "Preferences/.WindowMaker"
  - Set icon path list
  - Set default fonts to Helevetica family
  - Set DOCK_EXTRA_SPACE to 3
  - Set DOCK_DETTACH_THRESHOLD to 2 (multiple of icon size)

### src/window.c

  **[Configuration]**
  [@@ -755,9 +755,10 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L755-L765)
  Set `wwin->defined_user_flags.shared_appicon = 0` for GNUstep applications.

  **[Window managemen]t**
  [@@ -1161,6 +1162,15 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L1162-L1177)
  Fix moving down on height of title bar and right on border width (1 pixel) for windows which were already mapped before Workspace (and WindowMaker) started.

  **[Focus]**
  [@@ -1574,7 +1584,8 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L1584-L1592)
  Switch focus to GNUstep app menu (that is in `skip_window_list`). 
  Fixes the bug: menu-only application loses focus after right-click on appicon.

  **[Window management]**
  [@@ -2075,6 +2086,14 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L2086-L3000)
  Fix for VirtualBox VM window.

  **[Window management]**
  [@@ -2212,7 +2231,16 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L2231-L2247),
  [@@ -2266,7 +2294,12 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L2294-L2306)
  Titlebar button pixmaps changes handling if modifier key pressed.

  [@@ -2567,6 +2600,12 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L2600-L2612)
  **[Keyboard]**
  Grab Super\_L and Super\_R as modifiers. // _**FIXME**_

  **[Focus]**
  [@@ -2802,6 +2841,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L2841-L2848),
  [@@ -2818,6 +2858,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L2858-L2865),
  [@@ -2971,6 +3012,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L3012-L3019),
  [@@ -2982,6 +3024,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L3024-L3031)
  New resize/move concept: do not block focus changing code until resize/move finished.

  **[Window management]**
  [@@ -3100,6 +3143,15 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/window.c#L3143-L3158)
  Maximize/Unmaximize window when modifier+click on miniaturize titlebar button.

### src/workspace.c

  **[Integration]**
  [@@ -50,6 +50,9 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/workspace.c#L50-L59),
  [@@ -436,6 +439,9 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/workspace.c#L439-L448)
  Call XWWorkspaceDidChange() to update current workspace badge in Workspace application icon.

### src/xinerama.c

  **[Window management]**
  [@@ -306,7 +307,7 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/xinerame.c#L307-L314)
  Include Dock size in `usableArea` calculations only if Dock is visible.

  **[Window Management]**
  [@@ -315,6 +316,15 @@](https://github.com/trunkmaster/nextspace/blob/master/Applications/Workspace/WindowMaker/src/xinerama.c#L316-L331)
  Include IconYard size in `usableArea` calculations only if IconYard is visible.
    
