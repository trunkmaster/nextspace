/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
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

#ifndef __WORKSPACE_WM_WORKSPACE__
#define __WORKSPACE_WM_WORKSPACE__

#define MAX_DESKTOPNAME_WIDTH 64

typedef struct WDesktop {
  char *name;
  struct WDock *clip;
  RImage *map;
  WWindow *focused_window;
} WDesktop;

void wDesktopMake(WScreen *scr, int count);
int wDesktopNew(WScreen *scr);
int wGetDesktopNumber(WScreen *scr, const char *value);
Bool wDesktopDelete(WScreen *scr, int desktop);
void wDesktopChange(WScreen *scr, int desktop, WWindow *focus_win);
void wDesktopSaveFocusedWindow(WScreen *scr, int desktop, WWindow *wwin);
void wDesktopForceChange(WScreen *scr, int desktop, WWindow *focus_win);
WMenu *wDesktopMenuMake(WScreen *scr, Bool titled);
void wDesktopMenuUpdate(WScreen *scr, WMenu *menu);
void wDesktopMenuEdit(WScreen *scr);
void wDesktopSaveState(WScreen *scr);
void wDesktopRestoreState(WScreen *scr);
void wDesktopRename(WScreen *scr, int desktop, const char *name);
void wDesktopRelativeChange(WScreen *scr, int amount);

#endif /* __WORKSPACE_WM_WORKSPACE__ */
