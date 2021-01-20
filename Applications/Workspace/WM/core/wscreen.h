/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
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

#ifndef __WORKSPACE_WM_WSCREEN__
#define __WORKSPACE_WM_WSCREEN__

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <stdio.h>
#include <X11/Xutil.h>
#include <X11/Xlib.h>

#include <wraster.h>

#include "whashtable.h"

/* global settigns  */
extern char *_WINGS_progname;

/* Widgets */
/* typedef void WMWidget; */

/* Pre-definition of internal structs */
typedef struct WMColor		WMColor;
typedef struct WMPixmap		WMPixmap;
typedef struct WMView		WMView;
typedef struct WMDraggingInfo	WMDraggingInfo;
typedef struct WMFocusInfo	WMFocusInfo;

typedef struct WMScreen {
  Display *display;
  int screen;
  int depth;

  Colormap colormap;
  Visual *visual;
  Time lastEventTime;
  Window rootWin;
  WMView *rootView;
  RContext *rcontext;

  struct WMIMContext *imctx;
  struct _XftDraw *xftdraw;          /* shared XftDraw */

  /* application related */

  WMFocusInfo *focusInfo;

  RImage *applicationIconImage;      /* image (can have alpha channel) */
  WMPixmap *applicationIconPixmap; /* pixmap - no alpha channel */
  Window applicationIconWindow;

  struct WMWindow *windowList;       /* list of windows in the app */

  Window groupLeader;                /* the leader of the application */
  /* also used for other things */

  struct WMSelectionHandlers *selectionHandlerList;

  struct {
    unsigned int hasAppIcon:1;
    unsigned int simpleApplication:1;
  } aflags;

  Pixmap stipple;

  WMView *dragSourceView;
  WMDraggingInfo *dragInfo;

  /* colors */
  WMColor *white;
  WMColor *black;
  WMColor *gray;
  WMColor *darkGray;

  GC stippleGC;
  GC copyGC;
  GC clipGC;
  GC monoGC;                         /* GC for 1bpp visuals */
  GC xorGC;
  GC ixorGC;                         /* IncludeInferiors XOR */
  GC drawStringGC;                   /* for WMDrawString() */
  GC drawImStringGC;                 /* for WMDrawImageString() */

  struct WMFont *normalFont;
  struct WMFont *boldFont;
  WMHashTable *fontCache;
  Bool antialiasedText;

  unsigned int ignoredModifierMask; /* modifiers to ignore when typing txt */

  struct WMBalloon *balloon;


  WMPixmap *checkButtonImageOn;
  WMPixmap *checkButtonImageOff;

  WMPixmap *radioButtonImageOn;
  WMPixmap *radioButtonImageOff;

  WMPixmap *buttonArrow;
  WMPixmap *pushedButtonArrow;

  WMPixmap *scrollerDimple;

  WMPixmap *upArrow;
  WMPixmap *downArrow;
  WMPixmap *leftArrow;
  WMPixmap *rightArrow;

  WMPixmap *hiUpArrow;
  WMPixmap *hiDownArrow;
  WMPixmap *hiLeftArrow;
  WMPixmap *hiRightArrow;

  WMPixmap *pullDownIndicator;
  WMPixmap *popUpIndicator;

  WMPixmap *checkMark;

  WMPixmap *defaultObjectIcon;

  Cursor defaultCursor;

  Cursor textCursor;

  Cursor invisibleCursor;

  Atom attribsAtom;              /* GNUstepWindowAttributes */

  Atom deleteWindowAtom;         /* WM_DELETE_WINDOW */

  Atom protocolsAtom;            /* _XA_WM_PROTOCOLS */

  Atom clipboardAtom;            /* CLIPBOARD */

  Atom xdndAwareAtom;            /* XdndAware */
  Atom xdndSelectionAtom;
  Atom xdndEnterAtom;
  Atom xdndLeaveAtom;
  Atom xdndPositionAtom;
  Atom xdndDropAtom;
  Atom xdndFinishedAtom;
  Atom xdndTypeListAtom;
  Atom xdndActionListAtom;
  Atom xdndActionDescriptionAtom;
  Atom xdndStatusAtom;

  Atom xdndActionCopy;
  Atom xdndActionMove;
  Atom xdndActionLink;
  Atom xdndActionAsk;
  Atom xdndActionPrivate;

  Atom wmIconDragOffsetAtom;

  Atom wmStateAtom;              /* WM_STATE */
    
  Atom utf8String;

  Atom netwmName;
  Atom netwmIconName;
  Atom netwmIcon;

  /* stuff for detecting double-clicks */
  Time lastClickTime;            /* time of last mousedown event */
  Window lastClickWindow;        /* window of the last mousedown */

  struct WMView *modalView;
  unsigned modalLoop:1;
  unsigned ignoreNextDoubleClick:1;

  /*
   * New stuff in Window Maker 0.95.7
   * Added at the end of the structure to avoid breaking binary compatibility
   * with previous versions of the toolkit
   */
  WMPixmap *tristateButtonImageOn;
  WMPixmap *tristateButtonImageOff;
  WMPixmap *tristateButtonImageTri;
} WMScreen;

#define WMDRAWABLE(scr)	(scr)->rcontext->drawable

#endif /* __WORKSPACE_WM_WSCREEN__ */
