/*
 *  Workspace window manager
 *  Copyright (c) 2020-2021 Sergii Stoian
 *
 *  Window Maker window manager (xinerama.c)
 *  Copyright (c) 1997-2001 Alfredo K. Kojima
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

#ifndef __WORKSPACE_WM_XRANDR__
#define __WORKSPACE_WM_XRANDR__

#include "appicon.h"
#include "screen.h"
#include "window.h"

void wInitXrandr(WScreen *scr);
void wUpdateXrandrInfo(WScreen *scr);

#define wScreenHeads(scr) ((scr)->xrandr_info.count ? (scr)->xrandr_info.count : 1)

#define XFLAG_NONE	0x00
#define XFLAG_DEAD	0x01
#define XFLAG_MULTIPLE	0x02
#define XFLAG_PARTIAL	0x04

int wGetRectPlacementInfo(WScreen *scr, WMRect rect, int *flags);

int wGetHeadForRect(WScreen *scr, WMRect rect);

int wGetHeadForWindow(WWindow *wwin);

int wGetHeadForPoint(WScreen *scr, WMPoint point);

int wGetHeadForPointerLocation(WScreen *scr);

WMRect wGetRectForHead(WScreen *scr, int head);

WArea wGetUsableAreaForHead(WScreen *scr, int head, WArea *totalAreaPtr, Bool noicons);

WMPoint wGetPointToCenterRectInHead(WScreen *scr, int head, int width, int height);

Bool wWindowTouchesHead(WWindow *wwin, int head);
Bool wAppIconTouchesHead(WAppIcon *aicon, int head);

#endif /* __WORKSPACE_WM_XRANDR__ */
