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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef WMMENU_H_
#define WMMENU_H_

#include <CoreFoundation/CFRunLoop.h>

#include "wcore.h"

#define MI_DIAMOND	0
#define MI_CHECK	1
#define MI_MINIWINDOW	2
#define MI_HIDDEN	3
#define MI_SHADED	4

typedef struct WMenuEntry {
  int order;
  char *text;			       /* entry text */
  char *rtext;		       /* text to show in the right part */
  void (*callback)(struct WMenu *menu, struct WMenuEntry *entry);
  void (*free_cdata)(void *data);    /* proc to be used to free clientdata */
  void *clientdata;		       /* data to pass to callback */
  int cascade;		       /* cascade menu index */
  struct {
    unsigned int enabled:1;	       /* entry is selectable */
    unsigned int indicator:1;      /* left indicator */
    unsigned int indicator_on:1;
    unsigned int indicator_type:3;
    unsigned int editable:1;
  } flags;
} WMenuEntry;


typedef struct WMenu {
  struct WMenu *parent;
  struct WMenu *brother;

  time_t timestamp;		       /* for the root menu. Last time
                                        * menu was reloaded */

  /* decorations */
  struct WFrameWindow *frame;
  WCoreWindow *menu;		       /* the window menu */
  Pixmap menu_texture_data;
  int frame_x, frame_y;	       /* position of the frame in root*/

  WMenuEntry **entries;	       /* array of entries. This is shared
                                * by the menu and it's "brother" */
  short alloced_entries;	       /* number of entries allocated in
                                        * entry array */
  struct WMenu **cascades;	       /* array of cascades */
  short cascade_no;

  short entry_no;		       /* number of entries */
  short selected_entry;

  short entry_height;		       /* height of each entry */

  /*WMHandlerID timer;*/
  CFRunLoopTimerRef timer;		/* timer for the autoscroll */

  void *jump_back;                   /* jump back data */

  /* to be called when some entry is edited */
  void (*on_edit)(struct WMenu *menu, struct WMenuEntry *entry);
  /* to be called when destroyed */
  void (*on_destroy)(struct WMenu *menu);

  struct {
    unsigned int titled:1;
    unsigned int realized:1;       /* whether the window was configured */
    unsigned int app_menu:1;       /* this is a application or root menu */
    unsigned int mapped:1;	       /* if menu is already mapped on screen*/
    unsigned int buttoned:1;       /* if the close button is visible
                                    * (menu was torn off) */
    unsigned int open_to_left:1;   /* direction to open submenus */
    unsigned int lowered:1;

    unsigned int brother:1;	       /* if this is a copy of the menu*/
    unsigned int editing:1;
    unsigned int jump_back_pending:1;

    unsigned int inside_handler:1;
  } flags;
} WMenu;


void wMenuPaint(WMenu *menu);
void wMenuDestroy(WMenu *menu, int recurse);
void wMenuRealize(WMenu *menu);
WMenuEntry *wMenuInsertCascade(WMenu *menu, int index, const char *text,
                               WMenu *cascade);
WMenuEntry *wMenuInsertCallback(WMenu *menu, int index, const char *text,
                                void (*callback)(WMenu *menu, WMenuEntry *entry),
                                void *clientdata);

void wMenuEntrySetCascade(WMenu *menu, WMenuEntry *entry, WMenu *cascade);

#define wMenuAddCallback(menu, text, callback, data)    \
  wMenuInsertCallback(menu, -1, text, callback, data)

void wMenuRemoveItem(WMenu *menu, int index);

WMenu *wMenuCreate(WScreen *screen, const char *title, int main_menu);
WMenu *wMenuCreateForApp(WScreen *screen, const char *title, int main_menu);
void wMenuMap(WMenu *menu);
void wMenuMapAt(WMenu *menu, int x, int y, int keyboard);
#define wMenuMapCopyAt(menu, x, y) wMenuMapAt((menu)->brother, (x), (y), False)
void wMenuUnmap(WMenu *menu);
void wMenuSetEnabled(WMenu *menu, int index, int enable);
void wMenuMove(WMenu *menu, int x, int y, int submenus);
void wMenuEntryRemoveCascade(WMenu *menu, WMenuEntry *entry);
void wMenuScroll(WMenu *menu);
WMenu *wMenuUnderPointer(WScreen *screen);
void wMenuSaveState(WScreen *scr);
void wMenuRestoreState(WScreen *scr);

#endif
