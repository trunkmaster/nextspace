/* usermenu.c- user defined menu
 *
 *  Window Maker window manager
 *
 *  Copyright (c) hmmm... Should I put everybody's name here?
 *  Where's my lawyer?? -- ]d :D
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
 *
 * * * * * * * * *
 * User defined menu is good, but beer's always better
 * if someone wanna start hacking something, He heard...
 * TODO
 *  - enhance commands. (eg, exit, hide, list all app's member
 *    window and etc)
 *  - cache menu... dunno.. if people really use this feature :P
 *  - Violins, senseless violins!
 *  that's all, right now :P
 *  - external! WINGs menu editor.
 *  TODONOT
 *  - allow applications to share their menu. ] think it
 *    looks wierd since there still are more than 1 appicon.
 *
 *  Syntax...
 *  (
 *    "Program Name",
 *    ("Command 1", SHORTCUT, 1),
 *    ("Command 2", SHORTCUT, 2, ("Allowed_instant_1", "Allowed_instant_2")),
 *    ("Command 3", SHORTCUT, (3,4,5), ("Allowed_instant_1")),
 *    (
 *      "Submenu",
 *      ("Kill Command", KILL),
 *      ("Hide Command", HIDE),
 *      ("Hide Others Command", HIDE_OTHERS),
 *      ("Members", MEMBERS),
 *      ("Exit Command", EXIT)
 *    )
 *  )
 *
 *  Tips:
 *  - If you don't want short cut keys to be listed
 *    in the right side of entries, you can just put them
 *    in array instead of using the string directly.
 *
 */

#include "wconfig.h"

#ifdef USER_MENU

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xproto.h>
#include <X11/Xatom.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

#include "WindowMaker.h"
#include "menu.h"
#include "actions.h"
#include "keybind.h"
#include "xmodifier.h"
#include "misc.h"

#include "framewin.h"

#define MAX_SHORTCUT_LENGTH 32


typedef struct {
  WScreen *screen;
  WShortKey *key;
  int key_no;
} WUserMenuData;

static void notifyClient(WMenu * menu, WMenuEntry * entry)
{
  XEvent event;
  WUserMenuData *data = entry->clientdata;
  WScreen *scr = data->screen;
  Window window;
  int i;

  window = scr->focused_window->client_win;

  for (i = 0; i < data->key_no; i++) {
    event.xkey.type = KeyPress;
    event.xkey.display = dpy;
    event.xkey.window = window;
    event.xkey.root = DefaultRootWindow(dpy);
    event.xkey.subwindow = (Window) None;
    event.xkey.x = 0x0;
    event.xkey.y = 0x0;
    event.xkey.x_root = 0x0;
    event.xkey.y_root = 0x0;
    event.xkey.keycode = data->key[i].keycode;
    event.xkey.state = data->key[i].modifier;
    event.xkey.same_screen = True;
    event.xkey.time = CurrentTime;
    if (XSendEvent(dpy, window, False, KeyPressMask, &event)) {
      event.xkey.type = KeyRelease;
      event.xkey.time = CurrentTime;
      XSendEvent(dpy, window, True, KeyReleaseMask, &event);
    }
  }
}

static void removeUserMenudata(void *menudata)
{
  WUserMenuData *data = menudata;
  if (data->key)
    wfree(data->key);

  wfree(data);
}

static WUserMenuData *convertShortcuts(WScreen * scr, WMPropList * shortcut)
{
  WUserMenuData *data;
  KeySym ksym;
  char *k, buf[MAX_SHORTCUT_LENGTH], *b;
  int keycount, i, j, mod;

  if (WMIsPLString(shortcut)) {
    keycount = 1;
  } else if (WMIsPLArray(shortcut)) {
    keycount = WMGetPropListItemCount(shortcut);
  } else {
    return NULL;
  }

  data = wmalloc(sizeof(WUserMenuData));
  if (!data)
    return NULL;

  data->key = wmalloc(sizeof(WShortKey) * keycount);
  if (!data->key) {
    wfree(data);
    return NULL;
  }

  for (i = 0, j = 0; i < keycount; i++) {
    data->key[j].modifier = 0;
    if (WMIsPLArray(shortcut))
      wstrlcpy(buf, WMGetFromPLString(WMGetFromPLArray(shortcut, i)), MAX_SHORTCUT_LENGTH);
    else
      wstrlcpy(buf, WMGetFromPLString(shortcut), MAX_SHORTCUT_LENGTH);

    b = (char *)buf;

    while ((k = strchr(b, '+')) != NULL) {
      *k = 0;
      mod = wXModifierFromKey(b);
      if (mod < 0)
        break;

      data->key[j].modifier |= mod;
      b = k + 1;
    }

    ksym = XStringToKeysym(b);
    if (ksym == NoSymbol)
      continue;

    data->key[j].keycode = XKeysymToKeycode(dpy, ksym);
    if (data->key[j].keycode)
      j++;
  }

 keyover:

  /* get key */
  if (!j) {
    puts("fatal j");
    wfree(data->key);
    wfree(data);
    return NULL;
  }
  data->key_no = j;
  data->screen = scr;

  return data;
}

static WMenu *configureUserMenu(WScreen * scr, WMPropList * plum)
{
  char *mtitle;
  WMenu *menu = NULL;
  WMPropList *elem, *title, *command, *params;
  int count, i;
  WUserMenuData *data;

  if (!plum)
    return NULL;

  if (!WMIsPLArray(plum))
    return NULL;

  count = WMGetPropListItemCount(plum);
  if (!count)
    return NULL;

  elem = WMGetFromPLArray(plum, 0);
  if (!WMIsPLString(elem))
    return NULL;

  mtitle = WMGetFromPLString(elem);

  menu = wMenuCreateForApp(scr, mtitle, True);

  for (i = 1; i < count; i++) {
    elem = WMGetFromPLArray(plum, i);
    if (WMIsPLArray(WMGetFromPLArray(elem, 1))) {
      WMenu *submenu;
      WMenuEntry *mentry;

      submenu = configureUserMenu(scr, elem);
      if (submenu)
        mentry = wMenuAddCallback(menu, submenu->frame->title, NULL, NULL);
      wMenuEntrySetCascade(menu, mentry, submenu);
    } else {
      int idx = 0;
      WMPropList *instances = 0;

      title = WMGetFromPLArray(elem, idx++);
      command = WMGetFromPLArray(elem, idx++);
      if (WMGetPropListItemCount(elem) >= 3)
        params = WMGetFromPLArray(elem, idx++);

      if (!title || !command)
        return menu;

      if (!strcmp("SHORTCUT", WMGetFromPLString(command))) {
        WMenuEntry *entry;

        data = convertShortcuts(scr, params);
        if (data) {
          entry = wMenuAddCallback(menu, WMGetFromPLString(title),
                                   notifyClient, data);

          if (entry) {
            if (WMIsPLString(params))
              entry->rtext =
                GetShortcutString(WMGetFromPLString(params));

            entry->free_cdata = removeUserMenudata;

            if (WMGetPropListItemCount(elem) >= 4) {
              instances = WMGetFromPLArray(elem, idx++);
              if (WMIsPLArray(instances))
                if (instances && WMGetPropListItemCount(instances)
                    && WMIsPLArray(instances)) {
                  entry->instances =
                    WMRetainPropList(instances);
                }
            }
          }
        }
      }

    }
  }
  return menu;
}

void wUserMenuRefreshInstances(WMenu * menu, WWindow * wwin)
{
  int i, j, count, paintflag;

  paintflag = 0;

  if (!menu)
    return;

  for (i = 0; i < menu->entry_no; i++) {
    if (menu->entries[i]->instances) {
      WMPropList *ins;
      int oldflag;
      count = WMGetPropListItemCount(menu->entries[i]->instances);

      oldflag = menu->entries[i]->flags.enabled;
      menu->entries[i]->flags.enabled = 0;
      for (j = 0; j < count; j++) {
        ins = WMGetFromPLArray(menu->entries[i]->instances, j);
        if (!strcmp(wwin->wm_instance, WMGetFromPLString(ins))) {
          menu->entries[i]->flags.enabled = 1;
          break;
        }
      }
      if (oldflag != menu->entries[i]->flags.enabled)
        paintflag = 1;
    }
  }
  for (i = 0; i < menu->cascade_no; i++) {
    if (!menu->cascades[i]->flags.brother)
      wUserMenuRefreshInstances(menu->cascades[i], wwin);
    else
      wUserMenuRefreshInstances(menu->cascades[i]->brother, wwin);
  }

  if (paintflag)
    wMenuPaint(menu);
}

static WMenu *readUserMenuFile(WScreen *scr, const char *file_name)
{
  WMenu *menu = NULL;
  WMPropList *plum;

  plum = WMReadPropListFromFile(file_name);
  if (plum) {
    menu = configureUserMenu(scr, plum);
    WMReleasePropList(plum);
  }
  return menu;
}

WMenu *wUserMenuGet(WScreen * scr, WWindow * wwin)
{
  WMenu *menu = NULL;
  char *path = NULL;
  char *tmp;
  if (wwin && wwin->wm_instance && wwin->wm_class) {
    int len = strlen(wwin->wm_instance) + strlen(wwin->wm_class) + 7;
    tmp = wmalloc(len);
    snprintf(tmp, len, "%s.%s.menu", wwin->wm_instance, wwin->wm_class);
    path = wfindfile(DEF_USER_MENU_PATHS, tmp);
    wfree(tmp);

    if (!path)
      return NULL;

    menu = readUserMenuFile(scr, path);
    wfree(path);
  }
  return menu;
}

#endif				/* USER_MENU */
