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

#ifndef __WORKSPACE_WM_WIDGETS__
#define __WORKSPACE_WM_WIDGETS__

#include <assert.h>

#include "wpixmap.h"
#include "wcolor.h"

typedef void WMWidget;

typedef int WMClass;
enum {
  WC_Window	= 0,  // wwindow.c
  WC_Frame	= 1,  // wframe.c
  WC_Label	= 2,  // wlabel.c
  WC_UserWidget	= 128
};

/* All widgets must start with the following structure
 * in that order. Used for typecasting to get some generic data */
typedef struct WMWidgetType {
  WMClass widgetClass;
  struct WMView *view;
} WMWidgetType;

#define WMWidgetClass(widget)  	(((WMWidgetType*)(widget))->widgetClass)
#define WMWidgetView(widget)   	(((WMWidgetType*)(widget))->view)
#define WMWidgetWidth(widget)  	(WMWidgetView(widget)->size.width)
#define WMWidgetHeight(widget) 	(WMWidgetView(widget)->size.height)
#define WMWidgetXID(widget) 	(WMWidgetView(widget)->window)
#define WMWidgetScreen(widget) 	(WMWidgetView(widget)->screen)

#define CHECK_CLASS(widget, class) assert(WMWidgetClass(widget)==(class))

//---

WMClass WMRegisterUserWidget(void);

void WMRealizeWidget(WMWidget *w);
void WMMapWidget(WMWidget *w);
void WMUnmapWidget(WMWidget *w);
void WMDestroyWidget(WMWidget *widget);

void WMMoveWidget(WMWidget *w, int x, int y);
void WMResizeWidget(WMWidget *w, unsigned int width, unsigned int height);
void WMRedisplayWidget(WMWidget *w);

void WMSetWidgetBackgroundColor(WMWidget *w, WMColor *color);
void WMMapSubwidgets(WMWidget *w);

#endif /* __WORKSPACE_WM_WIDGETS__ */
