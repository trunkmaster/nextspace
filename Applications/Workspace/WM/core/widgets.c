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

#include "WM.h"
#include "WMcore.h"
#include "wscreen.h"
#include "wview.h"
#include "util.h"
#include "log_utils.h"

#include "widgets.h"

static int userWidgetCount = 0;

WMClass WMRegisterUserWidget(void)
{
  userWidgetCount++;
  return userWidgetCount + WC_UserWidget - 1;
}

/* Realizes the widget and all it's children. */
void WMRealizeWidget(WMWidget *w)
{
  WMRealizeView(WMWidgetView(w));
}

void WMMapWidget(WMWidget *w)
{
  WMMapView(WMWidgetView(w));
}

void WMUnmapWidget(WMWidget *w)
{
  WMUnmapView(WMWidgetView(w));
}

void WMDestroyWidget(WMWidget *widget)
{
  WMUnmapView(WMWidgetView(widget));
  WMDestroyView(WMWidgetView(widget));
}


void WMMoveWidget(WMWidget *w, int x, int y)
{
  WMMoveView(WMWidgetView(w), x, y);
}

void WMResizeWidget(WMWidget *w, unsigned int width, unsigned int height)
{
  WMResizeView(WMWidgetView(w), width, height);
}

void WMRedisplayWidget(WMWidget *w)
{
  WMRedisplayView(WMWidgetView(w));
}


void WMSetWidgetBackgroundColor(WMWidget *w, WMColor *color)
{
  WMSetViewBackgroundColor(WMWidgetView(w), color);
  if (WMWidgetView(w)->flags.mapped)
    WMRedisplayWidget(w);
}

static void makeChildrenAutomap(WMView *view, int flag)
{
  view = view->childrenList;

  while (view) {
    view->flags.mapWhenRealized = flag;
    makeChildrenAutomap(view, flag);

    view = view->nextSister;
  }
}

void WMMapSubwidgets(WMWidget *w)
{
  /* make sure that subwidgets created after the parent was realized
   *are mapped too */
  if (!WMWidgetView(w)->flags.realized) {
    makeChildrenAutomap(WMWidgetView(w), True);
  } else {
    WMMapSubviews(WMWidgetView(w));
  }
}
