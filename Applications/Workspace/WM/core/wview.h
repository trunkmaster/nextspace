/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
 *  Copyright (c) 2014 Window Maker Team
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

#ifndef __WORKSPACE_WM_WVIEW__
#define __WORKSPACE_WM_WVIEW__

#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFArray.h>

#include "wscreen.h"
#include "drawing.h"

typedef struct WMFocusInfo {
  WMView *toplevel;
  WMView *focused;    /* view that has the focus in this toplevel */
  struct WMFocusInfo *next;
} WMFocusInfo;

typedef struct WMViewDelegate {
    void *data;
    void (*didMove)(struct WMViewDelegate*, WMView*);
    void (*didResize)(struct WMViewDelegate*, WMView*);
    void (*willMove)(struct WMViewDelegate*, WMView*, int*, int*);
    void (*willResize)(struct WMViewDelegate*, WMView*,
                       unsigned int*, unsigned int*);
} WMViewDelegate;

typedef void WMWidget;

typedef struct WMView {
    struct WMScreen *screen;

    WMWidget *self;     /* must point to the widget the view belongs to */

    WMViewDelegate *delegate;

    Window window;

    WMSize size;

    short topOffs;
    short leftOffs;
    short bottomOffs;
    short rightOffs;

    WMPoint pos;

    struct WMView *nextFocusChain;     /* next/prev in focus chain */
    struct WMView *prevFocusChain;

    struct WMView *nextResponder;      /* next to receive keyboard events */

    struct WMView *parent;             /* parent WMView */

    struct WMView *childrenList;       /* first in list of child windows */

    struct WMView *nextSister;         /* next on parent's children list */

    CFMutableArrayRef eventHandlers;   /* event handlers for this window */

    unsigned long attribFlags;
    XSetWindowAttributes attribs;

    void *hangedData;                  /* data holder for user program */

    WMColor *backColor;
    WMPixmap *backImage;


    Cursor cursor;

    Atom *droppableTypes;
    struct WMDragSourceProcs      *dragSourceProcs;
    struct WMDragDestinationProcs *dragDestinationProcs;
    WMPixmap *dragImage;
    int helpContext;

    XIC xic;

    struct {
        unsigned int realized:1;
        unsigned int mapped:1;
        unsigned int parentDying:1;
        unsigned int dying:1;           /* the view is being destroyed */
        unsigned int topLevel:1;        /* is a top level window */
        unsigned int root:1;            /* is the root window */
        unsigned int mapWhenRealized:1; /* map the view when it's realized */
        unsigned int alreadyDead:1;     /* view was freed */

        unsigned int dontCompressMotion:1; /* motion notify event compress */
        unsigned int notifySizeChanged:1;
        unsigned int dontCompressExpose:1; /* expose event compress */

        /* toplevel only */
        unsigned int worksWhenModal:1;
        unsigned int pendingRelease1:1;
        unsigned int pendingRelease2:1;
        unsigned int pendingRelease3:1;
        unsigned int pendingRelease4:1;
        unsigned int pendingRelease5:1;
        unsigned int xdndHintSet:1;
    } flags;

    int refCount;
} WMView;

#define WMViewIsRealized(view)	(view)->flags.realized
#define WMViewIsMapped(view)	(view)->flags.mapped

#define WMViewDisplay(view)	(view)->screen->display
#define WMViewScreen(view)	(view)->screen
#define WMViewDrawable(view)	(view)->window

#define WMViewWidth(view)	(view)->size.width
#define WMViewHeight(view)	(view)->size.height

/* -- Functions -- */

WMView *WMGetViewForXWindow(Display *display, Window window);

WMView *WMCreateView(WMView *parent);

WMView *WMCreateTopView(WMScreen *screen);

WMView *WMCreateUnmanagedTopView(WMScreen *screen);

WMView *WMCreateRootView(WMScreen *screen);

void WMDestroyView(WMView *view);

void WMRealizeView(WMView *view);

void WMRedisplayView(WMView *view);

void WMReparentView(WMView *view, WMView *newParent, int x, int y);

void WMRaiseView(WMView *view);

void WMLowerView(WMView *view);

void WMMapView(WMView *view);

void WMMapSubviews(WMView *view);

void WMUnmapSubviews(WMView *view);

WMView *WMTopLevelOfView(WMView *view);

void WMUnmapView(WMView *view);

WMView *WMRetainView(WMView *view);

void WMReleaseView(WMView *view);

void WMMoveView(WMView *view, int x, int y);

void WMResizeView(WMView *view, unsigned int width, unsigned int height);

void WMSetViewBackgroundColor(WMView *view, WMColor *color);

void WMSetViewBackgroundPixmap(WMView *view, WMPixmap *pix);

void WMSetViewCursor(WMView *view, Cursor cursor);

void WMSetFocusOfTopLevel(WMView *toplevel, WMView *view);

WMView *WMFocusedViewOfToplevel(WMView *view);

void WMBroadcastMessage(WMView *targetParent, XEvent *event);

void WMDispatchMessage(WMView *target, XEvent *event);

/* ---[ wview.c ]--------------------------------------------------- */

Window WMViewXID(WMView *view);

void WMSetViewNotifySizeChanges(WMView *view, Bool flag);

void WMSetViewExpandsToParent(WMView *view, int topOffs, int leftOffs,
                              int rightOffs, int bottomOffs);

WMSize WMGetViewSize(WMView *view);

WMPoint WMGetViewPosition(WMView *view);

WMPoint WMGetViewScreenPosition(WMView *view);

WMWidget* WMWidgetOfView(WMView *view);

/* --- Notifications --- */
extern CFStringRef WMViewSizeDidChangeNotification;
extern CFStringRef WMViewDidRealizeNotification;

#endif /* __WORKSPACE_WM_WVIEWM_ */
