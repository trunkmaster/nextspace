/*
 *  Workspace window manager
 *
 *  Copyright (c) 2015-2021 Sergii Stoian
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

#ifndef __WORKSPACE_WM_MENU__
#define __WORKSPACE_WM_MENU__

#include <CoreFoundation/CFRunLoop.h>

#include "wcore.h"

#define MI_DIAMOND	0
#define MI_CHECK	1
#define MI_MINIWINDOW	2
#define MI_HIDDEN	3
#define MI_SHADED	4

#define MENU_WIDTH(m)	((m)->frame->core->width+2*(m)->frame->screen_ptr->frame_border_width)
#define MENU_HEIGHT(m)	((m)->frame->core->height+2*(m)->frame->screen_ptr->frame_border_width)

typedef struct WMenuItem {
  int order;
  char *text;			       /* entry text */
  char *rtext;                         /* text to show in the right part */
  void (*callback)(struct WMenu *menu, struct WMenuItem *item);
  void (*free_cdata)(void *data);      /* proc to be used to free clientdata */
  void *clientdata;		       /* data to pass to callback */
  int submenu_index;                         /* cascade menu index */
  struct {
    unsigned int enabled:1;	       /* item is selectable */
    unsigned int selected:1;	       /* item is highlighted */
    unsigned int indicator:1;          /* left indicator */
    unsigned int indicator_on:1;
    unsigned int indicator_type:3;
  } flags;
} WMenuItem;


typedef struct WMenu {
  struct WMenu *parent;
  struct WMenu *brother;
  struct WApplication *app;

  /* decorations */
  struct WFrameWindow *frame;
  WCoreWindow *menu;		       /* the menu window */
  Pixmap menu_texture_data;
  int frame_x, frame_y;	               /* position of the frame in root window */
  int old_frame_x, old_frame_y;	       /* position of the frame before slide */

  WMenuItem **items;                   /* array of items. shared by the menu and it's "brother" */
  short allocated_items;               /* number of items allocated in `items` array */
  short items_count;                   /* number of items in `items` array */
  short selected_item_index;           /* index of item in `items` array */
  short item_height;                   /* height of each item */
  
  struct WMenu **submenus;             /* array of submenus attached to items */
  short submenus_count;

  CFRunLoopTimerRef timer;             /* timer for the autoscroll */

  /* to be called when some item is edited */
  void (*on_edit)(struct WMenu *menu, struct WMenuItem *item);
  /* to be called when destroyed */
  void (*on_destroy)(struct WMenu *menu);

  struct {
    unsigned int titled:1;
    unsigned int realized:1;           /* whether the window was configured */
    unsigned int restored:1;           /* whether the menu was restored from saved state */
    unsigned int app_menu:1;           /* this is a application or root menu */
    unsigned int mapped:1;             /* if menu is already mapped on screen*/
    unsigned int hidden:1;             /* if menu was hidden on app deactivation */
    unsigned int tornoff:1;            /* if the close button is visible (menu was torn off) */
    unsigned int lowered:1;
    unsigned int brother:1;	       /* if this is a copy of the menu */
  } flags;
} WMenu;


void wMenuPaint(WMenu *menu);
void wMenuDestroy(WMenu *menu, int recurse);
void wMenuRealize(WMenu *menu);

WMenuItem *wMenuInsertSubmenu(WMenu *menu, int index, const char *text,
                               WMenu *submenu);
void wMenuItemSetSubmenu(WMenu *menu, WMenuItem *item, WMenu *submenu);
void wMenuItemRemoveSubmenu(WMenu *menu, WMenuItem *item);

WMenuItem *wMenuInsertItem(WMenu *menu, int index, const char *text,
                            void (*callback)(WMenu *menu, WMenuItem *index),
                            void *clientdata);
#define wMenuAddItem(menu, text, callback, data) wMenuInsertItem(menu, -1, text, callback, data)
void wMenuRemoveItem(WMenu *menu, int index);

WMenu *wMenuCreate(WScreen *screen, const char *title, int main_menu);
WMenu *wMenuCreateForApp(WScreen *screen, const char *title, int main_menu);
void wMenuMap(WMenu *menu);
void wMenuMapAt(WMenu *menu, int x, int y, int keyboard);
#define wMenuMapCopyAt(menu, x, y) wMenuMapAt((menu)->brother, (x), (y), False)
void wMenuUnmap(WMenu *menu);
void wMenuSetEnabled(WMenu *menu, int index, int enable);
void wMenuItemSetEnabled(WMenu *menu, WMenuItem *item, Bool enable);
void wMenuMove(WMenu *menu, int x, int y, int submenus);

void wMenuSlideIfNeeded(WMenu *menu);

WMenu *wMenuUnderPointer(WScreen *screen);
void wMenuSaveState(WScreen *scr);
void wMenuRestoreState(WScreen *scr);

#endif /* __WORKSPACE_WM_MENU__ */
