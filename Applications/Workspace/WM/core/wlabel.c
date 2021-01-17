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

#include "util.h"
#include "string_utils.h"

#include "wscreen.h"
#include "widgets.h"
#include "wevent.h"
#include "wpixmap.h"
#include "wcolor.h"
#include "drawing.h"
#include "wlabel.h"

#define DEFAULT_WIDTH		60
#define DEFAULT_HEIGHT		14
#define DEFAULT_ALIGNMENT	WALeft
#define DEFAULT_RELIEF		WRFlat
#define DEFAULT_IMAGE_POSITION	WIPNoImage

static void destroyLabel(WMLabel *lPtr);
static void paintLabel(WMLabel *lPtr);

static void handleEvents(XEvent *event, void *data);

WMLabel *WMCreateLabel(WMWidget *parent)
{
  WMLabel *lPtr;

  lPtr = wmalloc(sizeof(WMLabel));

  lPtr->widgetClass = WC_Label;

  lPtr->view = WMCreateView(WMVIEW(parent));
  if (!lPtr->view) {
    wfree(lPtr);
    return NULL;
  }
  lPtr->view->self = lPtr;

  lPtr->textColor = WMRetainColor(lPtr->view->screen->black);

  WMCreateEventHandler(lPtr->view, ExposureMask | StructureNotifyMask, handleEvents, lPtr);

  WMResizeView(lPtr->view, DEFAULT_WIDTH, DEFAULT_HEIGHT);
  lPtr->flags.alignment = DEFAULT_ALIGNMENT;
  lPtr->flags.relief = DEFAULT_RELIEF;
  lPtr->flags.imagePosition = DEFAULT_IMAGE_POSITION;
  lPtr->flags.noWrap = 1;

  return lPtr;
}

void WMSetLabelImage(WMLabel *lPtr, WMPixmap *image)
{
  if (lPtr->image != NULL)
    WMReleasePixmap(lPtr->image);

  if (image)
    lPtr->image = WMRetainPixmap(image);
  else
    lPtr->image = NULL;

  if (lPtr->view->flags.realized) {
    paintLabel(lPtr);
  }
}

WMPixmap *WMGetLabelImage(WMLabel *lPtr)
{
  return lPtr->image;
}

char *WMGetLabelText(WMLabel *lPtr)
{
  return lPtr->caption;
}

void WMSetLabelImagePosition(WMLabel *lPtr, WMImagePosition position)
{
  lPtr->flags.imagePosition = position;
  if (lPtr->view->flags.realized) {
    paintLabel(lPtr);
  }
}

void WMSetLabelTextAlignment(WMLabel *lPtr, WMAlignment alignment)
{
  lPtr->flags.alignment = alignment;
  if (lPtr->view->flags.realized) {
    paintLabel(lPtr);
  }
}

void WMSetLabelRelief(WMLabel *lPtr, WMReliefType relief)
{
  lPtr->flags.relief = relief;
  if (lPtr->view->flags.realized) {
    paintLabel(lPtr);
  }
}

void WMSetLabelText(WMLabel *lPtr, const char *text)
{
  if (lPtr->caption)
    wfree(lPtr->caption);

  if (text != NULL) {
    lPtr->caption = wstrdup(text);
  } else {
    lPtr->caption = NULL;
  }
  if (lPtr->view->flags.realized) {
    paintLabel(lPtr);
  }
}

WMFont *WMGetLabelFont(WMLabel *lPtr)
{
  return lPtr->font;
}

void WMSetLabelFont(WMLabel *lPtr, WMFont *font)
{
  if (lPtr->font != NULL)
    WMReleaseFont(lPtr->font);
  if (font)
    lPtr->font = WMRetainFont(font);
  else
    lPtr->font = NULL;

  if (lPtr->view->flags.realized) {
    paintLabel(lPtr);
  }
}

void WMSetLabelTextColor(WMLabel *lPtr, WMColor *color)
{
  if (lPtr->textColor)
    WMReleaseColor(lPtr->textColor);
  lPtr->textColor = WMRetainColor(color);

  if (lPtr->view->flags.realized) {
    paintLabel(lPtr);
  }
}

void WMSetLabelWraps(WMLabel *lPtr, Bool flag)
{
  flag = ((flag == 0) ? 0 : 1);
  if (lPtr->flags.noWrap != !flag) {
    lPtr->flags.noWrap = !flag;
    if (lPtr->view->flags.realized)
      paintLabel(lPtr);
  }
}

static void paintLabel(WMLabel *lPtr)
{
  WMScreen *scrPtr = lPtr->view->screen;

  WMPaintTextAndImage(lPtr->view, !lPtr->flags.noWrap,
                      lPtr->textColor ? lPtr->textColor : scrPtr->black,
                      (lPtr->font != NULL ? lPtr->font : scrPtr->normalFont),
                      lPtr->flags.relief, lPtr->caption,
                      lPtr->flags.alignment, lPtr->image, lPtr->flags.imagePosition, NULL, 0);
}

static void handleEvents(XEvent *event, void *data)
{
  WMLabel *lPtr = (WMLabel *) data;

  CHECK_CLASS(data, WC_Label);

  switch (event->type) {
  case Expose:
    if (event->xexpose.count != 0)
      break;
    paintLabel(lPtr);
    break;

  case DestroyNotify:
    destroyLabel(lPtr);
    break;
  }
}

static void destroyLabel(WMLabel *lPtr)
{
  if (lPtr->textColor)
    WMReleaseColor(lPtr->textColor);

  if (lPtr->caption)
    wfree(lPtr->caption);

  if (lPtr->font)
    WMReleaseFont(lPtr->font);

  if (lPtr->image)
    WMReleasePixmap(lPtr->image);

  wfree(lPtr);
}
