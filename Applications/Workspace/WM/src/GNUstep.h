/* GNUstep.h-- stuff for compatibility with GNUstep applications
 *
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */
#ifndef WMGNUSTEP_H_
#define WMGNUSTEP_H_

#include <X11/Xproto.h>

/* #define GNUSTEP_WM_MINIATURIZE_WINDOW "_GNUSTEP_WM_MINIATURIZE_WINDOW" */
/* #define GNUSTEP_WM_HIDE_APP "_GNUSTEP_WM_HIDE_APP" */
/* #define GNUSTEP_WM_ATTR_NAME "_GNUSTEP_WM_ATTR" */
/* #define GNUSTEP_TITLEBAR_STATE "_GNUSTEP_TITLEBAR_STATE" */

enum {
      WMTitleBarKey = 0,
      WMTitleBarNormal = 1,
      WMTitleBarMain = 2
};

#ifndef _DEFINED_GNUSTEP_WINDOW_INFO
#define	_DEFINED_GNUSTEP_WINDOW_INFO
/*
 * Window levels are taken from GNUstep (gui/AppKit/NSWindow.h)
 * NSDesktopWindowLevel intended to be the level at which things
 * on the desktop sit ... so you should be able
 * to put a desktop background just below it.
 *
 * Applications are actually permitted to use any value in the
 * range INT_MIN+1 to INT_MAX
 */
enum {
      // OPENSTEP  // MacOS  // GNUstep
      NSDesktopWindowLevel     = -1000, // --        // 2      // -1000
      NSNormalWindowLevel      = 0,     // 0         // 3      // 0
      NSFloatingWindowLevel    = 3,     // 3         // 4      // 3
      NSDockWindowLevel        = 5,     // 5         // 6      // 21
      NSSubmenuWindowLevel     = 10,    // 10        // 5      // 3
      NSTornOffMenuWindowLevel = 10,    // --        // 5      // 3
      NSMainMenuWindowLevel    = 20,    // 20        // 7      // 20
      NSStatusWindowLevel      = 21,    // --        // 8      // 21
      NSModalPanelWindowLevel  = 100,   // --        // 9      // 100
      NSPopUpMenuWindowLevel   = 101,   // --        // 10     // 101
      NSScreenSaverWindowLevel = 1000   // --        // 12     // 1000
};

/* window attributes */
enum {
      WMBorderlessWindowMask = 0,
      WMTitledWindowMask = 1,
      WMClosableWindowMask = 2,
      WMMiniaturizableWindowMask = 4,
      WMResizableWindowMask = 8,
      WMIconWindowMask = 64,
      WMMiniWindowMask = 128
};
#endif

/* window manager -> appkit notifications */
#define GNUSTEP_WM_NOTIFICATION		"GNUSTEP_WM_NOTIFICATION"


typedef struct {
  CARD32 flags;
  CARD32 window_style;
  CARD32 window_level;
  CARD32 reserved;
  Pixmap miniaturize_pixmap;	       /* pixmap for miniaturize button */
  Pixmap close_pixmap;	       /* pixmap for close button */
  Pixmap miniaturize_mask;	       /* miniaturize pixmap mask */
  Pixmap close_mask;		       /* close pixmap mask */
  CARD32 extra_flags;
} GNUstepWMAttributes;

#define GSWindowStyleAttr	(1<<0)
#define GSWindowLevelAttr	(1<<1)
#define GSMiniaturizePixmapAttr	(1<<3)
#define GSClosePixmapAttr	(1<<4)
#define GSMiniaturizeMaskAttr	(1<<5)
#define GSCloseMaskAttr		(1<<6)
#define GSExtraFlagsAttr	(1<<7)

/* extra flags */
#define GSDocumentEditedFlag	(1<<0)
/* #define GSWindowWillResizeNotificationsFlag     (1<<1) */ /* unused */
/* #define GSWindowWillMoveNotificationsFlag       (1<<2) */ /* unused */
#define GSNoApplicationIconFlag	(1<<5)

#define WMFHideOtherApplications 10
#define WMFHideApplication       12

#endif

