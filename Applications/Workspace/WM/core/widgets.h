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

#ifndef __WORKSPACE_WM_WIDGETS__
#define __WORKSPACE_WM_WIDGETS__

#include <stdnoreturn.h>

#include "wpixmap.h"
#include "wview.h"
#include "wcolor.h"

typedef int WMClass;

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
typedef struct WMWidgetType {
    WMClass widgetClass;
    struct WMView *view;

} WMWidgetType;

#define WMWidgetClass(widget)  	(((WMWidgetType*)(widget))->widgetClass)
#define WMWidgetView(widget)   	(((WMWidgetType*)(widget))->view)

#define WC_UserWidget	128

#define CHECK_CLASS(widget, class) assert(WMCLASS(widget)==(class))

#define WMCLASS(widget)  	(((WMWidgetType*)(widget))->widgetClass)
#define WMVIEW(widget)   	(((WMWidgetType*)(widget))->view)

/* -- Functions -- */

WMClass WMRegisterUserWidget(void);

WMScreen* WMOpenScreen(const char *display);

WMScreen* WMCreateScreenWithRContext(Display *display, int screen,
                                     RContext *context);

WMScreen* WMCreateScreen(Display *display, int screen);

WMScreen* WMCreateSimpleApplicationScreen(Display *display);

void WMBreakModalLoop(WMScreen *scr);

void WMRunModalLoop(WMScreen *scr, WMView *view);

RContext* WMScreenRContext(WMScreen *scr);

Display* WMScreenDisplay(WMScreen *scr);

int WMScreenDepth(WMScreen *scr);

void WMSetFocusToWidget(WMWidget *widget);

//---

WMScreen* WMWidgetScreen(WMWidget *w);

unsigned int WMScreenWidth(WMScreen *scr);

unsigned int WMScreenHeight(WMScreen *scr);

void WMUnmapWidget(WMWidget *w);

void WMMapWidget(WMWidget *w);

Bool WMWidgetIsMapped(WMWidget *w);

void WMRaiseWidget(WMWidget *w);

void WMLowerWidget(WMWidget *w);

void WMMoveWidget(WMWidget *w, int x, int y);

void WMResizeWidget(WMWidget *w, unsigned int width, unsigned int height);

void WMSetWidgetBackgroundColor(WMWidget *w, WMColor *color);

WMColor* WMGetWidgetBackgroundColor(WMWidget *w);

void WMSetWidgetBackgroundPixmap(WMWidget *w, WMPixmap *pix);

WMPixmap *WMGetWidgetBackgroundPixmap(WMWidget *w);

void WMMapSubwidgets(WMWidget *w);

void WMUnmapSubwidgets(WMWidget *w);

void WMRealizeWidget(WMWidget *w);

void WMReparentWidget(WMWidget *w, WMWidget *newParent, int x, int y);

void WMDestroyWidget(WMWidget *widget);

void WMHangData(WMWidget *widget, void *data);

void* WMGetHangedData(WMWidget *widget);

unsigned int WMWidgetWidth(WMWidget *w);

unsigned int WMWidgetHeight(WMWidget *w);

Window WMWidgetXID(WMWidget *w);

void WMRedisplayWidget(WMWidget *w);

#endif /* __WORKSPACE_WM_WIDGETS__ */
