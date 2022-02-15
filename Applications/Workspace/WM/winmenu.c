/*  Command menu for windows
 *
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

#include <core/WMcore.h>
#include <core/log_utils.h>

#include "WM.h"
#include "menu.h"
#include "window.h"
#include "framewin.h"
#include "stacking.h"
#include "xrandr.h"
#include "winmenu.h"

enum {
  WO_KEEP_ON_TOP,
  WO_KEEP_AT_BOTTOM,
  WO_OMNIPRESENT
};
static const char *const window_menu_items[] = {
  [WO_KEEP_ON_TOP]    = N_("Keep Above All Windows"),
  [WO_KEEP_AT_BOTTOM] = N_("Keep Below All Windows"),
  [WO_OMNIPRESENT]    = N_("Show on All Desktops")
};

static void execWindowCommand(WMenu *menu, WMenuItem *entry)
{
  WWindow *wwin = (WWindow *)entry->clientdata;

  switch (entry->order) {
  case WO_KEEP_ON_TOP:
    if (wwin->frame->core->stacking->window_level != NSFloatingWindowLevel)
      ChangeStackingLevel(wwin->frame->core, NSFloatingWindowLevel);
    else
      ChangeStackingLevel(wwin->frame->core, NSNormalWindowLevel);
    break;

  case WO_KEEP_AT_BOTTOM:
    if (wwin->frame->core->stacking->window_level != NSSunkenWindowLevel)
      ChangeStackingLevel(wwin->frame->core, NSSunkenWindowLevel);
    else
      ChangeStackingLevel(wwin->frame->core, NSNormalWindowLevel);
    break;

  case WO_OMNIPRESENT:
    wWindowSetOmnipresent(wwin, !wwin->flags.omnipresent);
    break;
  }
}

static void updateWindowMenu(WMenu *menu, WWindow * wwin)
{
  /* keep on top check */
  menu->items[WO_KEEP_ON_TOP]->clientdata = wwin;
  menu->items[WO_KEEP_ON_TOP]->flags.indicator_on =
    (wwin->frame->core->stacking->window_level == NSFloatingWindowLevel) ? 1 : 0;
  wMenuSetEnabled(menu, WO_KEEP_ON_TOP, !wwin->flags.miniaturized);

  /* keep at bottom check */
  menu->items[WO_KEEP_AT_BOTTOM]->clientdata = wwin;
  menu->items[WO_KEEP_AT_BOTTOM]->flags.indicator_on =
    (wwin->frame->core->stacking->window_level == NSSunkenWindowLevel) ? 1 : 0;
  wMenuSetEnabled(menu, WO_KEEP_AT_BOTTOM, !wwin->flags.miniaturized);

  /* omnipresent check */
  menu->items[WO_OMNIPRESENT]->clientdata = wwin;
  menu->items[WO_OMNIPRESENT]->flags.indicator_on = IS_OMNIPRESENT(wwin);

  menu->flags.realized = 0;
  wMenuRealize(menu);
}

static WMenu *createWindowMenu(WScreen * scr)
{
  WMenu *menu;
  WMenuItem *item;
  int i;

  menu = wMenuCreate(scr, NULL, False);
  if (!menu) {
    WMLogWarning(_("could not create submenu for window menu"));
    return NULL;
  }

  for (i = 0; i < wlengthof(window_menu_items); i++) {
    item = wMenuAddItem(menu, _(window_menu_items[i]), execWindowCommand, NULL);
    item->flags.indicator = 1;
    item->flags.indicator_type = MI_CHECK;
  }

  return menu;
}

void CloseWindowMenu(WScreen * scr)
{
  if (scr->window_menu) {
    if (scr->window_menu->flags.mapped)
      wMenuUnmap(scr->window_menu);

    if (scr->window_menu->items[0]->clientdata) {
      WWindow *wwin = (WWindow *) scr->window_menu->items[0]->clientdata;

      wwin->flags.menu_open_for_me = 0;
    }
    scr->window_menu->items[0]->clientdata = NULL;
  }
}

void OpenWindowMenu(WWindow *wwin, int x, int y, int keyboard)
{
  WScreen *scr = wwin->screen;
  WMenu *menu;
  WMRect rect;

  wwin->flags.menu_open_for_me = 1;
  if (!scr->window_menu) {
    scr->window_menu = createWindowMenu(scr);
  }
  menu = scr->window_menu;
  if (menu->flags.mapped) {
    wMenuUnmap(menu);
    if (menu->items[0]->clientdata == wwin) {
      return;
    }
  }
  updateWindowMenu(menu, wwin);

  /* Specific menu position */
  x -= menu->frame->core->width / 2;
  if (x + menu->frame->core->width > wwin->frame_x + wwin->frame->core->width)
    x = wwin->frame_x + wwin->frame->core->width - menu->frame->core->width;
  if (x < wwin->frame_x)
    x = wwin->frame_x;

  /* Common menu position */
  rect = wGetRectForHead(menu->frame->screen_ptr,
                         wGetHeadForPointerLocation(menu->frame->screen_ptr));
  if (x < rect.pos.x - menu->frame->core->width / 2) {
    x = rect.pos.x - menu->frame->core->width / 2;
  }
  if (y < rect.pos.y) {
    y = rect.pos.y;
  }

  /* Map menu on screen */
  if (!wwin->flags.internal_window) {
    wMenuMapAt(menu, x, y, keyboard);
  }
}

void DestroyWindowMenu(WScreen *scr)
{
  if (scr->window_menu) {
    wMenuDestroy(scr->window_menu, True);
    scr->window_menu = NULL;
  }
}
