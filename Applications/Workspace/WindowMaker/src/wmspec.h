/*  wmspec.h-- support for the wm-spec Hints
 *
 *  Window Maker window manager
 *
 *  Copyright (c) 1998-2003 Alfredo K. Kojima
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



#ifndef _WMSPEC_H_
#define _WMSPEC_H_

#include "screen.h"
#include "window.h"
#include <X11/Xlib.h>

void wNETWMInitStuff(WScreen *scr);
void wNETWMCleanup(WScreen *scr);
void wNETWMUpdateWorkarea(WScreen *scr);
Bool wNETWMGetUsableArea(WScreen *scr, int head, WArea *area);
void wNETWMCheckInitialClientState(WWindow *wwin);
void wNETWMCheckInitialFrameState(WWindow *wwin);
Bool wNETWMProcessClientMessage(XClientMessageEvent *event);
void wNETWMCheckClientHints(WWindow *wwin, int *layer, int *workspace);
void wNETWMCheckClientHintChange(WWindow *wwin, XPropertyEvent *event);
void wNETWMUpdateActions(WWindow *wwin, Bool del);
void wNETWMUpdateDesktop(WScreen *scr);
void wNETWMPositionSplash(WWindow *wwin, int *x, int *y, int width, int height);
int wNETWMGetPidForWindow(Window window);
int wNETWMGetCurrentDesktopFromHint(WScreen *scr);
char *wNETWMGetIconName(Window window);
char *wNETWMGetWindowName(Window window);
void wNETFrameExtents(WWindow *wwin);
void wNETCleanupFrameExtents(WWindow *wwin);
RImage *get_window_image_from_x11(Window window);
#endif
