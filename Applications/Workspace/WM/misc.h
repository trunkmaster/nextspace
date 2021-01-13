/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  Window Maker window manager
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

#ifndef __WORKSPACE_WM_MISC__
#define __WORKSPACE_WM_MISC__

#include "defaults.h"
#include "appicon.h"

Bool wGetWindowName(Display *dpy, Window win, char **winname);
Bool wGetWindowIconName(Display *dpy, Window win, char **iconname);

void wMoveWindow(Window win, int from_x, int from_y, int to_x, int to_y);
void wSlideWindowList(Window wins[], int n, int from_x, int from_y, int to_x, int to_y);
void ParseWindowName(CFStringRef value, char **winstance, char **wclass, const char *where);

static inline void wSlideWindow(Window win, int from_x, int from_y, int to_x, int to_y)
{
  wSlideWindowList(&win, 1, from_x, from_y, to_x, to_y);
}

/* Helper is a 'wmsetbg' subprocess with sets the background for the current workspace */
Bool wStartBackgroundHelper(WScreen *scr);
void wSendHelperMessage(WScreen *scr, char type, int workspace, const char *msg);

char *ShrinkString(WMFont *font, const char *string, int width);
char *ExpandOptions(WScreen * scr, const char *cmdline);

char *GetShortcutString(const char *text);
char *GetShortcutKey(WShortKey key);

char *EscapeWM_CLASS(const char *name, const char *class);
char *wGetCommandForWindow(Window win);

void wSetupCommandEnvironment(WScreen *scr);
void wExecuteShellCommand(WScreen *scr, const char *command);
Bool wRelaunchWindow(WWindow *wwin);

int wGetWVisualID(int screen);
void wSetWVisualID(int screen, int val);

CFTypeRef wGetNotificationInfoValue(CFDictionaryRef theDict, CFStringRef key);

#endif /* __WORKSPACE_WM_MISC__ */
