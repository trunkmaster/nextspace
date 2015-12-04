/*
 *  Window Maker window manager
 *
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */

#ifndef WMACTIONS_H_
#define WMACTIONS_H_

#include "window.h"

#define MAX_HORIZONTAL 	1
#define MAX_VERTICAL 	2
#define MAX_IGNORE_XINERAMA 4
#define MAX_KEYBOARD 8

void wSetFocusTo(WScreen *scr, WWindow *wwin);

int wMouseMoveWindow(WWindow *wwin, XEvent *ev);
int wKeyboardMoveResizeWindow(WWindow *wwin);

void wMouseResizeWindow(WWindow *wwin, XEvent *ev);

void wShadeWindow(WWindow *wwin);
void wUnshadeWindow(WWindow *wwin);

void wIconifyWindow(WWindow *wwin);
void wDeiconifyWindow(WWindow *wwin);

#ifndef LITE
void wSelectWindows(WScreen *scr, XEvent *ev);
#endif

void wSelectWindow(WWindow *wwin, Bool flag);
void wUnselectWindows(WScreen *scr);

void wMaximizeWindow(WWindow *wwin, int directions);
void wUnmaximizeWindow(WWindow *wwin);

void wHideOtherApplications(WWindow *wwin);
void wShowAllWindows(WScreen *scr);

void wHideApplication(WApplication *wapp);
void wUnhideApplication(WApplication *wapp, Bool miniwindows,
                        Bool bringToCurrentWS);

void wRefreshDesktop(WScreen *scr);

void wArrangeIcons(WScreen *scr, Bool arrangeAll);

void wMakeWindowVisible(WWindow *wwin);

void wFullscreenWindow(WWindow *wwin);
void wUnfullscreenWindow(WWindow *wwin);


#endif

