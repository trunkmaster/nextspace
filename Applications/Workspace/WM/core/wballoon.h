/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2001 Dan Pascu
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#ifndef __WORKSPACE_WM_WBALLOON__
#define __WORKSPACE_WM_WBALLOON__

struct WMBalloon *WMCreateBalloon(WMScreen *scr);

void WMBalloonHandleEnterView(WMView *view);

void WMBalloonHandleLeaveView(WMView *view);

/* ---[ WINGs/wballoon.c ]------------------------------------------------ */

void WMSetBalloonTextForView(const char *text, WMView *view);

void WMSetBalloonTextAlignment(WMScreen *scr, WMAlignment alignment);

void WMSetBalloonFont(WMScreen *scr, WMFont *font);

void WMSetBalloonTextColor(WMScreen *scr, WMColor *color);

void WMSetBalloonDelay(WMScreen *scr, int delay);

void WMSetBalloonEnabled(WMScreen *scr, Bool flag);

#endif /* __WORKSPACE_WM_WBALLOON__ */
