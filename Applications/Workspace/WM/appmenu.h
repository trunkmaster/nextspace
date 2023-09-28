/*
 *  Workspace window manager
 *  Copyright (c) 2015-present Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1998-2003 Alfredo K. Kojima
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
 
#include "screen.h"
#include "menu.h"
#include "application.h"

WMenu *wApplicationMenuCreate(WScreen *scr, WApplication *wapp);
void wApplicationMenuDestroy(WApplication *wapp);
void wApplicationMenuOpen(WApplication *wapp, int x, int y);
void wApplicationMenuHide(WMenu *menu);
void wApplicationMenuShow(WMenu *menu);

void wApplicationMenuSaveState(WMenu *main_menu, CFMutableArrayRef menus_state);
void wApplicationMenuRestoreFromState(WMenu *menu, CFArrayRef state);

WMenuItem *wMenuItemWithTitle(WMenu *menu, char *title);

Bool wApplicationMenuHandleKeyPress(struct WWindow *focused_window, XEvent *event);
