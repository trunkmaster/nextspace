/*
 *  Workspace window manager
 *
 *  Copyright (c) 2000 Alfredo K. Kojima
 *  Copyright (c) 2015- Sergii Stoian
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

#include <core/util.h>

#include <core/widgets.h>
#include <core/wevent.h>
#include <core/wcolor.h>
#include <core/drawing.h>

#include "geomview.h"

struct WMGeometryView {
  WMClass widgetClass;
  WMView *view;

  WMColor *color;
  WMColor *bgColor;

  WMFont *font;

  WMSize textSize;

  union {
    struct {
      int x, y;
    } pos;
    struct {
      unsigned width, height;
    } size;
  } data;

  unsigned showPosition:1;
};

static void handleEvents(XEvent * event, void *clientData);
static void paint(WGeometryView * gview);

WGeometryView *WCreateGeometryView(WMScreen * scr)
{
  WGeometryView *gview;
  char buffer[64];
  static WMClass widgetClass = 0;

  if (!widgetClass) {
    widgetClass = WMRegisterUserWidget();
  }

  gview = malloc(sizeof(WGeometryView));
  if (!gview) {
    return NULL;
  }
  memset(gview, 0, sizeof(WGeometryView));

  gview->widgetClass = widgetClass;

  gview->view = WMCreateTopView(scr);
  if (!gview->view) {
    wfree(gview);

    return NULL;
  }
  gview->view->self = gview;

  gview->font = WMSystemFontOfSize(scr, 12);
  if (!gview->font) {
    WMDestroyView(gview->view);
    wfree(gview);

    return NULL;
  }

  gview->bgColor = WMCreateRGBColor(scr, 0x3333, 0x6666, 0x9999, True);
  gview->color = WMWhiteColor(scr);

  WMCreateEventHandler(gview->view, ExposureMask, handleEvents, gview);

  snprintf(buffer, sizeof(buffer), "%+05i,  %+05i", 0, 0);

  gview->textSize.width = WMWidthOfString(gview->font, buffer, strlen(buffer));
  gview->textSize.height = WMFontHeight(gview->font);

  WMSetWidgetBackgroundColor(gview, gview->bgColor);

  WMResizeView(gview->view, gview->textSize.width + 8, gview->textSize.height + 6);

  return gview;
}

void WSetGeometryViewShownPosition(WGeometryView * gview, int x, int y)
{
  gview->showPosition = 1;
  gview->data.pos.x = x;
  gview->data.pos.y = y;

  paint(gview);
}

void WSetGeometryViewShownSize(WGeometryView * gview, unsigned width, unsigned height)
{
  gview->showPosition = 0;
  gview->data.size.width = width;
  gview->data.size.height = height;

  paint(gview);
}

static void paint(WGeometryView * gview)
{
  char buffer[64];

  if (gview->showPosition) {
    snprintf(buffer, sizeof(buffer), "%+5i , %+5i    ", gview->data.pos.x, gview->data.pos.y);
  } else {
    snprintf(buffer, sizeof(buffer), "%+5i x %+5i    ",
             gview->data.size.width, gview->data.size.height);
  }

  WMDrawImageString(WMViewScreen(gview->view),
                    WMViewDrawable(gview->view),
                    gview->color, gview->bgColor, gview->font,
                    (WMViewWidth(gview->view) - gview->textSize.width) / 2,
                    (WMViewHeight(gview->view) - gview->textSize.height) / 2, buffer, strlen(buffer));

  WMDrawRelief(WMViewScreen(gview->view), WMViewDrawable(gview->view),
               0, 0, WMViewWidth(gview->view), WMViewHeight(gview->view), WRSimple);
}

static void handleEvents(XEvent * event, void *clientData)
{
  WGeometryView *gview = (WGeometryView *) clientData;

  switch (event->type) {
  case Expose:
    paint(gview);
    break;

  }
}
