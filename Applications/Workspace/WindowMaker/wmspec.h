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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */



#ifndef _WMSPEC_H_
#define _WMSPEC_H_

#include <screen.h>
#include <window.h>
#include <X11/Xlib.h>

void wNETWMInitStuff(WScreen *scr);
void wNETWMCleanup(WScreen *scr);
void wNETWMUpdateWorkarea(WScreen *scr, WArea usableArea);
Bool wNETWMGetUsableArea(WScreen *scr, int head, WArea *area);
Bool wNETWMCheckInitialClientState(WWindow *wwin);
Bool wNETWMProcessClientMessage(XClientMessageEvent *event);
Bool wNETWMCheckClientHints(WWindow *wwin, int *layer, int *workspace);
Bool wNETWMCheckClientHintChange(WWindow *wwin, XPropertyEvent *event);
void wNETWMShowingDesktop(WScreen *scr, Bool show);
void wNETWMUpdateActions(WWindow *wwin, Bool del);
void wNETWMUpdateDesktop(WScreen *scr);
void wNETWMPositionSplash(WWindow *wwin, int *x, int *y, int width, int height);
int wNETWMGetPidForWindow(Window window);
int wNETWMGetCurrentDesktopFromHint(WScreen *scr);
char *wNETWMGetIconName(Window window);
char *wNETWMGetWindowName(Window window);
#endif
