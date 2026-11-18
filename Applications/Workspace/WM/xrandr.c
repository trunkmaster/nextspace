/*
 *  Workspace window manager
 *  Copyright (c) 2020-2021 Sergii Stoian
 *
 *  Window Maker window manager (xinerama.c)
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
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

#ifdef USE_XRANDR
#include <X11/extensions/Xrandr.h>
#endif

#include <core/WMcore.h>
#include <core/util.h>
#include <core/log_utils.h>

#include "screen.h"
#include "window.h"
#include "framewin.h"
#include "placement.h"
#include "dock.h"
#include "stdio.h"
#include "defaults.h"
#include "xrandr.h"

void wInitXrandr(WScreen *scr)
{
  WXrandrInfo *info = &scr->xrandr_info;
  int major_version, minor_version;

  info->primary_head = 0;
  info->screens = NULL;
  info->count = 0;

#ifdef USE_XRANDR
  if (XRRQueryExtension(dpy, &info->event_base, &info->error_base) == True) {
    XRRQueryVersion(dpy, &major_version, &minor_version);
    WMLogInfo("[xrandr.c] Use XRandR %i.%i, event base:%i, error base:%i\n", major_version,
              minor_version, info->event_base, info->error_base);
    wUpdateXrandrInfo(scr);
	} else {
    WMLogInfo("[xrandr.c] Use of XRRQueryExtension failed. This merits investigation.\n");
	}
#else
    WMLogInfo("[xrandr.c] no XRandR extension available.\n");
#endif
}

void wUpdateXrandrInfo(WScreen *scr)
{
#ifdef USE_XRANDR
  WXrandrInfo *info = &scr->xrandr_info;
  XRRScreenResources *screen_res = XRRGetScreenResources(dpy, scr->root_win);
  RROutput primary_output;
  XRROutputInfo *output_info;
  XRRCrtcInfo *crtc_info;
  int i;

  if (screen_res != NULL) {
    if (info->screens == NULL) {
      info->screens = wmalloc(sizeof(WMRect) * (screen_res->noutput + 1));
    }
    if (screen_res->noutput != 0) {
      primary_output = XRRGetOutputPrimary(dpy, scr->root_win);
      for (i = 0; i < screen_res->noutput; i++) {
        output_info = XRRGetOutputInfo(dpy, screen_res, screen_res->outputs[i]);
        if (screen_res->outputs[i] == primary_output) {
          info->primary_head = i;
        }
        if (output_info->crtc) {
          crtc_info = XRRGetCrtcInfo(dpy, screen_res, output_info->crtc);

          info->screens[i].pos.x = crtc_info->x;
          info->screens[i].pos.y = crtc_info->y;
          info->screens[i].size.width = crtc_info->width;
          info->screens[i].size.height = crtc_info->height;

          XRRFreeCrtcInfo(crtc_info);
        }
        XRRFreeOutputInfo(output_info);
      }
      info->count = i;
    }
    XRRFreeScreenResources(screen_res);
  }
#endif
}

int wGetRectPlacementInfo(WScreen *scr, WMRect rect, int *flags)
{
  int best;
  unsigned long area, totalArea;
  int i;
  int rx = rect.pos.x;
  int ry = rect.pos.y;
  int rw = rect.size.width;
  int rh = rect.size.height;

  wassertrv(flags != NULL, 0);

  best = -1;
  area = 0;
  totalArea = 0;

  *flags = XFLAG_NONE;

  if (scr->xrandr_info.count <= 1) {
    unsigned long a;

    a = calcIntersectionArea(rx, ry, rw, rh, 0, 0, scr->width, scr->height);

    if (a == 0) {
      *flags |= XFLAG_DEAD;
    } else if (a != rw * rh) {
      *flags |= XFLAG_PARTIAL;
    }

    return scr->xrandr_info.primary_head;
  }

  for (i = 0; i < wScreenHeads(scr); i++) {
    unsigned long a;

    a = calcIntersectionArea(
        rx, ry, rw, rh, scr->xrandr_info.screens[i].pos.x, scr->xrandr_info.screens[i].pos.y,
        scr->xrandr_info.screens[i].size.width, scr->xrandr_info.screens[i].size.height);

    totalArea += a;
    if (a > area) {
      if (best != -1)
        *flags |= XFLAG_MULTIPLE;
      area = a;
      best = i;
    }
  }

  if (best == -1) {
    *flags |= XFLAG_DEAD;
    best = wGetHeadForPointerLocation(scr);
  } else if (totalArea != rw * rh)
    *flags |= XFLAG_PARTIAL;

  return best;
}

/* get the head that covers most of the rectangle */
int wGetHeadForRect(WScreen *scr, WMRect rect)
{
  int best;
  unsigned long area;
  int i;
  int rx = rect.pos.x;
  int ry = rect.pos.y;
  int rw = rect.size.width;
  int rh = rect.size.height;

  if (!scr->xrandr_info.count)
    return scr->xrandr_info.primary_head;

  best = -1;
  area = 0;

  for (i = 0; i < wScreenHeads(scr); i++) {
    unsigned long a;

    a = calcIntersectionArea(
        rx, ry, rw, rh, scr->xrandr_info.screens[i].pos.x, scr->xrandr_info.screens[i].pos.y,
        scr->xrandr_info.screens[i].size.width, scr->xrandr_info.screens[i].size.height);

    if (a > area) {
      area = a;
      best = i;
    }
  }

  /*
   * in case rect is in dead space, return valid head
   */
  if (best == -1)
    best = wGetHeadForPointerLocation(scr);

  return best;
}

Bool wWindowTouchesHead(WWindow *wwin, int head)
{
  WScreen *scr;
  WMRect rect;
  int a;

  if (!wwin || !wwin->frame)
    return False;

  scr = wwin->screen;
  rect = wGetRectForHead(scr, head);
  a = calcIntersectionArea(wwin->frame_x, wwin->frame_y, wwin->frame->core->width,
                           wwin->frame->core->height, rect.pos.x, rect.pos.y, rect.size.width,
                           rect.size.height);

  return (a != 0);
}

Bool wAppIconTouchesHead(WAppIcon *aicon, int head)
{
  WScreen *scr;
  WMRect rect;
  int a;

  if (!aicon || !aicon->icon)
    return False;

  scr = aicon->icon->core->screen_ptr;
  rect = wGetRectForHead(scr, head);
  a = calcIntersectionArea(aicon->x_pos, aicon->y_pos, aicon->icon->core->width,
                           aicon->icon->core->height, rect.pos.x, rect.pos.y, rect.size.width,
                           rect.size.height);

  return (a != 0);
}

int wGetHeadForWindow(WWindow *wwin)
{
  WMRect rect;

  if (wwin == NULL || wwin->frame == NULL)
    return wDefaultScreen()->xrandr_info.primary_head;

  rect.pos.x = wwin->frame_x;
  rect.pos.y = wwin->frame_y;
  rect.size.width = wwin->frame->core->width;
  rect.size.height = wwin->frame->core->height;

  return wGetHeadForRect(wwin->screen, rect);
}

int wGetHeadForPoint(WScreen *scr, WMPoint point)
{
  int i;

  for (i = 0; i < scr->xrandr_info.count; i++) {
    WMRect *rect = &scr->xrandr_info.screens[i];

    if ((unsigned)(point.x - rect->pos.x) < rect->size.width &&
        (unsigned)(point.y - rect->pos.y) < rect->size.height)
      return i;
  }
  return scr->xrandr_info.primary_head;
}

int wGetHeadForPointerLocation(WScreen *scr)
{
  WMPoint point;
  Window bla;
  int ble;
  unsigned int blo;

  if (!scr->xrandr_info.count)
    return scr->xrandr_info.primary_head;

  if (!XQueryPointer(dpy, scr->root_win, &bla, &bla, &point.x, &point.y, &ble, &ble, &blo)) {
    return scr->xrandr_info.primary_head;
  }

  return wGetHeadForPoint(scr, point);
}

/* get the dimensions of the head */
WMRect wGetRectForHead(WScreen *scr, int head)
{
  WMRect rect;

  if (head < scr->xrandr_info.count) {
    rect.pos.x = scr->xrandr_info.screens[head].pos.x;
    rect.pos.y = scr->xrandr_info.screens[head].pos.y;
    rect.size.width = scr->xrandr_info.screens[head].size.width;
    rect.size.height = scr->xrandr_info.screens[head].size.height;
  } else {
    rect.pos.x = 0;
    rect.pos.y = 0;
    rect.size.width = scr->width;
    rect.size.height = scr->height;
  }

  return rect;
}

// FIXME: what does `noicon` mean? "Don't cover icons"? "Don't take into account icons?"
WArea wGetUsableAreaForHead(WScreen *scr, int head, WArea *totalAreaPtr, Bool noicons)
{
  WArea totalArea, usableArea;
  WMRect rect = wGetRectForHead(scr, head);

  totalArea.x1 = rect.pos.x;
  totalArea.y1 = rect.pos.y;
  totalArea.x2 = totalArea.x1 + rect.size.width;
  totalArea.y2 = totalArea.y1 + rect.size.height;

  if (totalAreaPtr != NULL)
    *totalAreaPtr = totalArea;

  if (head < wScreenHeads(scr)) {
    usableArea = noicons ? scr->totalUsableArea[head] : scr->usableArea[head];
  } else
    usableArea = totalArea;

  if (noicons) {
    /* check if user wants dock covered */
    if (scr->dock && scr->dock->mapped && wPreferences.no_window_over_dock &&
        wAppIconTouchesHead(scr->dock->icon_array[0], head)) {
      int offset = wPreferences.icon_size + DOCK_EXTRA_SPACE;

      if (scr->dock->on_right_side)
        usableArea.x2 -= offset;
      else
        usableArea.x1 += offset;
    }

    // scr->totalUsableArea includes right-side Dock but excludes Icon Yard.
    // scr->usableArea covers full display (head) resolution.
    // FIXME: will it be more logical to synchronize var names and meaning? like this:
    // 	`usableArea` =  display size - Dock - Icon Yard
    // 	`totalUsableAraea` = display size
    if (!scr->flags.icon_yard_mapped) {
      usableArea.y2 += wPreferences.icon_size;
    }

    /* check if icons are on the same side as dock, and adjust if not done already */
    if (scr->dock && wPreferences.no_window_over_icons && !wPreferences.no_window_over_dock &&
        (wPreferences.icon_yard & IY_VERT)) {
      int offset = wPreferences.icon_size + DOCK_EXTRA_SPACE;

      if (scr->dock->on_right_side && (wPreferences.icon_yard & IY_RIGHT))
        usableArea.x2 -= offset;
      /* can't use IY_LEFT in if, it's 0 ... */
      if (!scr->dock->on_right_side && !(wPreferences.icon_yard & IY_RIGHT))
        usableArea.x1 += offset;
    }
  }

  return usableArea;
}

WMPoint wGetPointToCenterRectInHead(WScreen *scr, int head, int width, int height)
{
  WMPoint p;
  WMRect rect = wGetRectForHead(scr, head);

  p.x = rect.pos.x + (rect.size.width - width) / 2;
  p.y = rect.pos.y + (rect.size.height - height) / 2;

  return p;
}
