/* WINGs.h
 *
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2001 Alfredo K. Kojima
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

#ifndef __WORKSPACE_WM_WINGS__
#define __WORKSPACE_WM_WINGS__

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <stdio.h>
#include <X11/Xutil.h>
#include <X11/Xlib.h>

#include <wraster.h>

#include <WMcore/WMcore.h>
#include <WMcore/hashtable.h>

#ifdef USE_PANGO
#include <pango/pango.h>
#endif


#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */
#if 0
}
#endif

/* global settigns  */
#define DOUBLE_BUFFER   1

extern char *_WINGS_progname;

typedef unsigned long WMPixel;

typedef struct {
    unsigned int width;
    unsigned int height;
} WMSize;

typedef struct {
    int x;
    int y;
} WMPoint;

typedef struct {
    WMPoint pos;
    WMSize size;
} WMRect;

#define ClientMessageMask	(1L<<30)

/* frame title positions */
typedef enum {
    WTPNoTitle,
    WTPAboveTop,
    WTPAtTop,
    WTPBelowTop,
    WTPAboveBottom,
    WTPAtBottom,
    WTPBelowBottom
} WMTitlePosition;

/* relief types */
typedef enum {
    WRFlat,
    WRSimple,
    WRRaised,
    WRSunken,
    WRGroove,
    WRRidge,
    WRPushed
} WMReliefType;

/* alignment types */
typedef enum {
    WALeft,
    WACenter,
    WARight,
    WAJustified		       /* not valid for textfields */
} WMAlignment;

/* image position */
typedef enum {
    WIPNoImage,
    WIPImageOnly,
    WIPLeft,
    WIPRight,
    WIPBelow,
    WIPAbove,
    WIPOverlaps
} WMImagePosition;

/* system images */
#define WSIReturnArrow			1
#define WSIHighlightedReturnArrow	2
#define WSIScrollerDimple		3
#define WSIArrowLeft			4
#define WSIHighlightedArrowLeft	        5
#define WSIArrowRight			6
#define WSIHighlightedArrowRight	7
#define WSIArrowUp			8
#define WSIHighlightedArrowUp		9
#define WSIArrowDown			10
#define WSIHighlightedArrowDown		11
#define WSICheckMark			12

/* alert panel return values */
enum {
    WAPRDefault = 1,   // NSAlertDefaultReturn = 1
    WAPRAlternate = 0, // NSAlertAlternateReturn = 0
    WAPROther = -1,
    WAPRError = -2
};

typedef void WMWidget;
typedef struct W_View	WMView;
typedef struct W_Color	WMColor;
typedef struct W_Font	WMFont;
typedef struct W_Pixmap	WMPixmap;

/* Pre-definition of internal structs */
typedef struct W_Color		W_Color;
typedef struct W_Pixmap		W_Pixmap;
typedef struct W_View		W_View;
typedef struct W_DraggingInfo	W_DraggingInfo;
typedef struct W_FocusInfo	W_FocusInfo;

typedef struct W_Screen {
    Display *display;
    int screen;
    int depth;

    Colormap colormap;
    Visual *visual;
    Time lastEventTime;
    Window rootWin;
    W_View *rootView;
    RContext *rcontext;

    struct W_IMContext *imctx;
    struct _XftDraw *xftdraw;          /* shared XftDraw */

    /* application related */

    W_FocusInfo *focusInfo;

    RImage *applicationIconImage;      /* image (can have alpha channel) */
    W_Pixmap *applicationIconPixmap; /* pixmap - no alpha channel */
    Window applicationIconWindow;

    struct W_Window *windowList;       /* list of windows in the app */

    Window groupLeader;                /* the leader of the application */
                                       /* also used for other things */

    struct W_SelectionHandlers *selectionHandlerList;

    struct {
        unsigned int hasAppIcon:1;
        unsigned int simpleApplication:1;
    } aflags;

    Pixmap stipple;

    W_View *dragSourceView;
    W_DraggingInfo *dragInfo;

    /* colors */
    W_Color *white;
    W_Color *black;
    W_Color *gray;
    W_Color *darkGray;

    GC stippleGC;
    GC copyGC;
    GC clipGC;
    GC monoGC;                         /* GC for 1bpp visuals */
    GC xorGC;
    GC ixorGC;                         /* IncludeInferiors XOR */
    GC drawStringGC;                   /* for WMDrawString() */
    GC drawImStringGC;                 /* for WMDrawImageString() */

    struct W_Font *normalFont;
    struct W_Font *boldFont;
    WMHashTable *fontCache;
    Bool antialiasedText;

    unsigned int ignoredModifierMask; /* modifiers to ignore when typing txt */

    struct W_Balloon *balloon;


    W_Pixmap *checkButtonImageOn;
    W_Pixmap *checkButtonImageOff;

    W_Pixmap *radioButtonImageOn;
    W_Pixmap *radioButtonImageOff;

    W_Pixmap *buttonArrow;
    W_Pixmap *pushedButtonArrow;

    W_Pixmap *scrollerDimple;

    W_Pixmap *upArrow;
    W_Pixmap *downArrow;
    W_Pixmap *leftArrow;
    W_Pixmap *rightArrow;

    W_Pixmap *hiUpArrow;
    W_Pixmap *hiDownArrow;
    W_Pixmap *hiLeftArrow;
    W_Pixmap *hiRightArrow;

    W_Pixmap *pullDownIndicator;
    W_Pixmap *popUpIndicator;

    W_Pixmap *checkMark;

    W_Pixmap *defaultObjectIcon;

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

    struct W_View *modalView;
    unsigned modalLoop:1;
    unsigned ignoreNextDoubleClick:1;

    /*
     * New stuff in Window Maker 0.95.7
     * Added at the end of the structure to avoid breaking binary compatibility
     * with previous versions of the toolkit
     */
    W_Pixmap *tristateButtonImageOn;
    W_Pixmap *tristateButtonImageOff;
    W_Pixmap *tristateButtonImageTri;

} W_Screen;
typedef struct W_Screen WMScreen;

#define W_DRAWABLE(scr)		(scr)->rcontext->drawable

#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif /* _WINGS_H_ */
