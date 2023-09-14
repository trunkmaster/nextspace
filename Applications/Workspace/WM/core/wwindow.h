/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
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

#ifndef __WORKSPACE_WM_WWINDOW__
#define __WORKSPACE_WM_WWINDOW__

#include "widgets.h"
#include "wview.h"

/* self is set to the widget from where the callback is being called and
 * clientData to the data set to with WMSetClientData() */
typedef void WMAction(WMWidget *self, void *clientData);
/* same as WMAction, but for stuff that arent widgets */
typedef void WMAction2(void *self, void *clientData);

typedef struct WMWindow {
  WMClass widgetClass;
  WMView *view;

  struct WMWindow *nextPtr;	/* next in the window list */

  struct WMWindow *owner;

  char *title;

  WMPixmap *miniImage;	/* miniwindow */
  char     *miniTitle;

  char *wname;

  WMSize  resizeIncrement;
  WMSize  baseSize;
  WMSize  minSize;
  WMSize  maxSize;
  WMPoint minAspect;
  WMPoint maxAspect;

  WMPoint upos;
  WMPoint ppos;

  WMAction *closeAction;
  void     *closeData;

  int level;

  struct {
    unsigned style:4;
    unsigned configured:1;
    unsigned documentEdited:1;

    unsigned setUPos:1;
    unsigned setPPos:1;
    unsigned setAspect:1;
  } flags;
} WMWindow;
/* typedef struct WMWindow WMWindow; */

/* ----------------------------------------------------------------------- */

WMWindow* WMCreateWindow(WMScreen *screen);

WMWindow* WMCreateWindowWithStyle(WMScreen *screen, int style);

/* WMWindow* WMCreatePanelWithStyleForWindow(WMWindow *owner, const char *name, int style); */
/* WMWindow* WMCreatePanelForWindow(WMWindow *owner, const char *name); */
/* void WMChangePanelOwner(WMWindow *win, WMWindow *newOwner); */

void WMSetWindowTitle(WMWindow *wPtr, const char *title);

void WMSetWindowMiniwindowTitle(WMWindow *win, const char *title);

void WMSetWindowMiniwindowImage(WMWindow *win, RImage *image);

void WMSetWindowMiniwindowPixmap(WMWindow *win, WMPixmap *pixmap);

void WMSetWindowCloseAction(WMWindow *win, WMAction *action, void *clientData);

void WMSetWindowInitialPosition(WMWindow *win, int x, int y);

void WMSetWindowUserPosition(WMWindow *win, int x, int y);

void WMSetWindowAspectRatio(WMWindow *win, int minX, int minY, int maxX, int maxY);

void WMSetWindowMaxSize(WMWindow *win, unsigned width, unsigned height);

void WMSetWindowMinSize(WMWindow *win, unsigned width, unsigned height);

void WMSetWindowBaseSize(WMWindow *win, unsigned width, unsigned height);

void WMSetWindowResizeIncrements(WMWindow *win, unsigned wIncr, unsigned hIncr);

void WMSetWindowLevel(WMWindow *win, int level);

void WMSetWindowDocumentEdited(WMWindow *win, Bool flag);

void WMCloseWindow(WMWindow *win);

#endif /* __WORKSPACE_WM_WWINDOWM_ */
