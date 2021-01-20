/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
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

#ifndef __WORKSPACE_WM_WAPPRESOURCE__
#define __WORKSPACE_WM_WAPPRESOURCE__

#include "wpixmap.h"

void WMInitApplication(WMScreen *scr);

Bool WMApplicationInitialized(void);

/* ---[ WINGs/wappresource.c ]-------------------------------------------- */

void WMSetApplicationIconImage(WMScreen *app, RImage *image);

RImage* WMGetApplicationIconImage(WMScreen *app);

void WMSetApplicationIconPixmap(WMScreen *app, WMPixmap *icon);

WMPixmap* WMGetApplicationIconPixmap(WMScreen *app);

/* If color==NULL it will use the default color for panels: ae/aa/ae */
WMPixmap* WMCreateApplicationIconBlendedPixmap(WMScreen *scr, const RColor *color);

void WMSetApplicationIconWindow(WMScreen *scr, Window window);

/* ---[ WINGs/wapplication.c ]-------------------------------------------- */

void WMInitializeApplication(const char *applicationName, int *argc, char **argv);

/* You're supposed to call this funtion before exiting so WINGs can terminate properly */
void WMReleaseApplication(void);

/* /\* don't free the returned string *\/ */
char* WMGetApplicationName(void);

#endif /* __WORKSPACE_WM_WAPPRESOURCE__ */
