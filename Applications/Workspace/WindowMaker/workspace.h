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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */

#ifndef WMWORKSPACE_H_
#define WMWORKSPACE_H_



typedef struct WWorkspace {
    char *name;
#ifdef VIRTUAL_DESKTOP
    int width, height;
    int view_x, view_y;
#endif
    struct WDock *clip;
} WWorkspace;

void wWorkspaceMake(WScreen *scr, int count);
int wWorkspaceNew(WScreen *scr);
Bool wWorkspaceDelete(WScreen *scr, int workspace);
void wWorkspaceChange(WScreen *scr, int workspace);
void wWorkspaceForceChange(WScreen *scr, int workspace);
#ifdef VIRTUAL_DESKTOP
void wWorkspaceUpdateEdge(WScreen *scr);
void wWorkspaceRaiseEdge(WScreen *scr);
void wWorkspaceLowerEdge(WScreen *scr);
void wWorkspaceResizeViewport(WScreen *scr, int workspace);
Bool wWorkspaceSetViewport(WScreen *scr, int workspace, int view_x, int view_y);
void wWorkspaceKeyboardMoveDesktop(WScreen *scr, WMPoint direction);

#define VEC_LEFT    wmkpoint(-1,0)
#define VEC_RIGHT   wmkpoint(1,0)
#define VEC_UP	    wmkpoint(0,-1)
#define VEC_DOWN    wmkpoint(0,1)

#endif


WMenu *wWorkspaceMenuMake(WScreen *scr, Bool titled);
void wWorkspaceMenuUpdate(WScreen *scr, WMenu *menu);

void wWorkspaceMenuEdit(WScreen *scr);

void wWorkspaceSaveState(WScreen *scr, WMPropList *old_state);
void wWorkspaceRestoreState(WScreen *scr);

void wWorkspaceRename(WScreen *scr, int workspace, char *name);

void wWorkspaceRelativeChange(WScreen *scr, int amount);

#endif
