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

Overview
========

GNUstep.h.patch
"src_WindowMaker.h.patch"
    Synchronize NS*WindowLevel with GNUstep's (defined in AppKit/NSWindow.h)
"src_defaults.c.patch"
    Miniwindow tile - setMiniWindowTile
"src dialog.c.patch"
    Path to history file changed from "/WindowMaker/History" to
    "/.AppInfo/WindowMaker/History". This path used to store running commands
    in "Run" panel.
"src_event.c.patch"
"src_framewin.c.patch"
"src_icon.c.patch"
"src_main.c.patch"
"src_screen.h.patch"
"src_wconfig.h.in.patch"
"src_window.c.patch"
"WINGs_userdefaults.c.patch"
"WINGs_wcolorpanel.c.patch"
