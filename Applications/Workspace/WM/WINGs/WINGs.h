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

#ifndef _WINGS_H_
#define _WINGS_H_

#include <wraster.h>
#include <WINGs/WUtil.h>
#include <X11/Xlib.h>

#define WINGS_H_VERSION  20150508


#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */
#if 0
}
#endif


#ifdef __STDC_VERSION__
# if __STDC_VERSION__ >= 201112L
/*
 * Ideally, we would like to include the proper header to have 'noreturn' properly
 * defined (that's what is done for the rest of the code)
 * However, as we're a public API file we can't do that in a portable fashion, so
 * we just stick to plain STD C11 keyword
 */
#  define _wings_noreturn _Noreturn
# else
#  define _wings_noreturn /**/
# endif
#else
#define _wings_noreturn /**/
#endif

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

/* drag operations */
typedef enum {
    WDOperationNone = 0,
    WDOperationCopy,
    WDOperationMove,
    WDOperationLink,
    WDOperationAsk,
    WDOperationPrivate
} WMDragOperationType;


typedef enum {
    WMGrayModeColorPanel = 1,
    WMRGBModeColorPanel = 2,
    WMCMYKModeColorPanel = 3,
    WMHSBModeColorPanel = 4,
    WMCustomPaletteModeColorPanel = 5,
    WMColorListModeColorPanel = 6,
    WMWheelModeColorPanel = 7
} WMColorPanelMode;

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

/* types of input observers */
enum {
    WIReadMask = (1 << 0),
    WIWriteMask = (1 << 1),
    WIExceptMask = (1 << 2)
};

typedef int W_Class;

enum {
    WC_Window = 0,
    WC_Frame = 1,
    WC_Label = 2,
    WC_Button = 3,
    WC_TextField = 4,
    WC_Scroller	= 5,
    WC_ScrollView = 6,
    WC_List = 7,
    WC_Browser = 8,
    WC_PopUpButton = 9,
    WC_ColorWell = 10,
    WC_Slider = 11,
    WC_Matrix = 12,		       /* not ready */
    WC_SplitView = 13,
    WC_TabView = 14,
    WC_ProgressIndicator = 15,
    WC_MenuView = 16,
    WC_Ruler = 17,
    WC_Text = 18,
    WC_Box = 19
};

/* All widgets must start with the following structure
 * in that order. Used for typecasting to get some generic data */
typedef struct W_WidgetType {
    W_Class widgetClass;
    struct W_View *view;

} W_WidgetType;

#define WMWidgetClass(widget)  	(((W_WidgetType*)(widget))->widgetClass)
#define WMWidgetView(widget)   	(((W_WidgetType*)(widget))->view)


/* widgets */
typedef void WMWidget;

typedef struct W_Pixmap WMPixmap;
typedef struct W_Font	WMFont;
typedef struct W_Color	WMColor;
typedef struct W_Screen WMScreen;
typedef struct W_View   WMView;
typedef struct W_Window WMWindow;
typedef struct W_Frame  WMFrame;
typedef struct W_Label  WMLabel;

/* ---[from WINGsP.h ]---------------------------------------------------- */
#include <X11/Xutil.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <stdio.h>

#ifdef USE_PANGO
#include <pango/pango.h>
#endif
/* global settigns  */

#define DOUBLE_BUFFER   1
#define SCROLLER_WIDTH	20

typedef struct _WINGsConfiguration {
    char *systemFont;
    char *boldSystemFont;
    int  defaultFontSize;
    Bool antialiasedText;
    char *floppyPath;
    unsigned doubleClickDelay;
    unsigned mouseWheelUp;
    unsigned mouseWheelDown;
} _WINGsConfiguration;

extern char *_WINGS_progname;
extern _WINGsConfiguration WINGsConfiguration;
extern struct W_Application WMApplication;
/* Pre-definition of internal structs */
typedef struct W_Color  W_Color;
typedef struct W_Pixmap W_Pixmap;
typedef struct W_View   W_View;
typedef struct W_Screen W_Screen;

typedef struct W_FocusInfo {
  W_View *toplevel;
  W_View *focused;    /* view that has the focus in this toplevel */
  struct W_FocusInfo *next;
} W_FocusInfo;

#include <WINGs/dragcommon.h>
/* #include <WINGs/wview.h> */
  
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
    W_DraggingInfo dragInfo;

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

#define W_DRAWABLE(scr)		(scr)->rcontext->drawable
/* ---[ WINGsP.h ]-------------------------------------------------------- */

typedef void WMEventProc(XEvent *event, void *clientData);
typedef void WMEventHook(XEvent *event);


/* self is set to the widget from where the callback is being called and
 * clientData to the data set to with WMSetClientData() */
typedef void WMAction(WMWidget *self, void *clientData);
/* same as WMAction, but for stuff that arent widgets */
typedef void WMAction2(void *self, void *clientData);

typedef void WMSelectionCallback(WMView *view, Atom selection, Atom target,
                                 Time timestamp, void *cdata, WMData *data);


/* ---[ WINGs/wapplication.c ]-------------------------------------------- */
#include <WINGs/wapplication.h>
/* ---[ WINGs/widgets.c ]------------------------------------------------- */
#include <WINGs/widgets.h>
/* ---[ WINGs/wappresource.c ]-------------------------------------------- */
#include <WINGs/wappresource.h>
/* ---[ WINGs/wevent.c ]-------------------------------------------------- */
#include <WINGs/wevent.h>
/* ---[ WINGs/selection.c ]----------------------------------------------- */
#include <WINGs/selection.h>
/* ---[ WINGs/dragcommon.c ]---------------------------------------------- */
/* #include <WINGs/dragcommon.h> */
/* ---[ WINGs/dragsource.c ]---------------------------------------------- */
#include <WINGs/dragsource.h>
/* ---[ WINGs/dragdestination.c ]----------------------------------------- */
#include <WINGs/dragdestination.h>
/* ---[ WINGs/wfont.c ]--------------------------------------------------- */
#include <WINGs/wfont.h>
/* ---[ WINGs/wpixmap.c ]------------------------------------------------- */
#include <WINGs/wpixmap.h>
/* ---[ WINGs/wcolor.c ]-------------------------------------------------- */
#include <WINGs/wcolor.h>
/* ---[ WINGs/wview.c ]--------------------------------------------------- */
#include <WINGs/wview.h>
/* ---[ WINGs/wballoon.c ]------------------------------------------------ */
#include <WINGs/wballoon.h>
/* ---[ WINGs/wwindow.c ]------------------------------------------------- */
#include <WINGs/wwindow.h>
/* ---[ WINGs/wlabel.c ]-------------------------------------------------- */
#include <WINGs/wlabel.h>
/* ---[ WINGs/wframe.c ]-------------------------------------------------- */
#include <WINGs/wframe.h>
/* ---[ WINGs/configuration.c ]------------------------------------------- */
#include <WINGs/configuration.h>
/* ---[ WINGs/wmisc.c ]--------------------------------------------------- */
#include <WINGs/wmisc.h>

#ifdef __cplusplus
}
#endif /* __cplusplus */


/* These definitions are not meant to be seen outside this file */
#undef _wings_noreturn


#endif
