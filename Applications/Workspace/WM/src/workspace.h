/* workspace.c- Workspace management
 *
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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef __WORKSPACE_WM_WORKSPACE__
#define __WORKSPACE_WM_WORKSPACE__

typedef struct WWorkspace {
  char *name;
  struct WDock *clip;
  RImage *map;
  WWindow *focused_window;
} WWorkspace;

void wWorkspaceMake(WScreen *scr, int count);
int wWorkspaceNew(WScreen *scr);
int wGetWorkspaceNumber(WScreen *scr, const char *value);
Bool wWorkspaceDelete(WScreen *scr, int workspace);
void wWorkspaceChange(WScreen *scr, int workspace, WWindow *focus_win);
void wWorkspaceSaveFocusedWindow(WScreen *scr, int workspace, WWindow *wwin);
void wWorkspaceForceChange(WScreen *scr, int workspace, WWindow *focus_win);
WMenu *wWorkspaceMenuMake(WScreen *scr, Bool titled);
void wWorkspaceMenuUpdate(WScreen *scr, WMenu *menu);
void wWorkspaceMenuEdit(WScreen *scr);
void wWorkspaceSaveState(WScreen *scr, WMPropList *old_state);
void wWorkspaceRestoreState(WScreen *scr);
void wWorkspaceRename(WScreen *scr, int workspace, const char *name);
void wWorkspaceRelativeChange(WScreen *scr, int amount);

#endif
