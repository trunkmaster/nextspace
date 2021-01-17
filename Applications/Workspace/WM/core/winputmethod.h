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

#ifndef __WORKSPACE_WM_WINPUTMETHOD__
#define __WORKSPACE_WM_WINPUTMETHOD__

void WMInitIM(WMScreen *scr);

void WMCreateIC(WMView *view);

void WMDestroyIC(WMView *view);

void WMFocusIC(WMView *view);

void WMUnFocusIC(WMView *view);

void WMSetPreeditPositon(WMView *view, int x, int y);

int WMLookupString(WMView *view, XKeyPressedEvent *event, char *buffer,
                   int buflen, KeySym *keysym, Status *status);

#endif /* __WORKSPACE_WM_WINPUTMETHOD__ */
