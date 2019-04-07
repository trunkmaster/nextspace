/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2013 Window Maker Team
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
#ifndef WMMISC_H_
#define WMMISC_H_

#include "defaults.h"
#include "keybind.h"
#include "appicon.h"

Bool wFetchName(Display *dpy, Window win, char **winname);
Bool wGetIconName(Display *dpy, Window win, char **iconname);
Bool UpdateDomainFile(WDDomain * domain);

void move_window(Window win, int from_x, int from_y, int to_x, int to_y);
void slide_windows(Window wins[], int n, int from_x, int from_y, int to_x, int to_y);
void ParseWindowName(WMPropList *value, char **winstance, char **wclass, const char *where);

static inline void slide_window(Window win, int from_x, int from_y, int to_x, int to_y)
{
	slide_windows(&win, 1, from_x, from_y, to_x, to_y);
}

/* Helper is a 'wmsetbg' subprocess with sets the background for the current workspace */
Bool start_bg_helper(WScreen *scr);
void SendHelperMessage(WScreen *scr, char type, int workspace, const char *msg);

char *ShrinkString(WMFont *font, const char *string, int width);
char *FindImage(const char *paths, const char *file);
char *ExpandOptions(WScreen * scr, const char *cmdline);
char *GetShortcutString(const char *text);
char *GetShortcutKey(WShortKey key);
char *EscapeWM_CLASS(const char *name, const char *class);
char *StrConcatDot(const char *a, const char *b);
char *GetCommandForWindow(Window win);
#endif
