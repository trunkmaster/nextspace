/* winmenu.c - command menu for windows
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

#include "wconfig.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/XKBlib.h>

#include <WMcore/memory.h>
#include <WMcore/string.h>
#include <WMcore/usleep.h>

#include "WindowMaker.h"
#include "actions.h"
#include "menu.h"
#include "main.h"
#include "window.h"
#include "client.h"
#include "application.h"
#include "keybind.h"
#include "misc.h"
#include "framewin.h"
#include "workspace.h"
#include "stacking.h"
#include "icon.h"
#include "xrandr.h"
#include "winmenu.h"

#include "dock.h"
#include <Workspace+WM.h>


static WMenu *makeWorkspaceMenu(WScreen *scr);
static WMenu *makeOptionsMenu(WScreen *scr);
static WMenu *makeMaximizeMenu(WScreen *scr);

/*
 * Define the Menu entry that will be present in the Window menu
 *
 * The order of this list defines the order in which they will appear;
 * make sure to keep the structure below aligned with the list because
 * the constant index is used in many places.
 */
enum
  {
   MC_OTHERMAX,
   MC_SHADE,
   MC_MOVERESIZE,
   MC_SELECT,
   MC_CHANGEWKSPC,
   MC_OPTIONS,
   MC_MAXIMIZE,
   MC_MINIATURIZE,
   MC_HIDE,
   MC_RELAUNCH,
   MC_CLOSE,
   MC_KILL
  };

static const struct {
  const char *label;
  WMenu *(*generate_submenu)(WScreen *scr);
} window_menu_entries[] = {
                           [MC_OTHERMAX]    = { N_("Maximize"), makeMaximizeMenu },
                           [MC_SHADE]       = { N_("Shade"), NULL },
                           [MC_MOVERESIZE]  = { N_("Resize/Move"), NULL },
                           [MC_SELECT]      = { N_("Select"), NULL },
                           [MC_CHANGEWKSPC] = { N_("Move To"), makeWorkspaceMenu },
                           [MC_OPTIONS]     = { N_("Options"), makeOptionsMenu }
};

/*
 * Defines the menu entries for the Options sub-menu
 *
 * These options will be placed at the beginning of the menu, the rest will
 * be populated with the Window Shortcut possibilities
 */
enum
  {
   WO_KEEP_ON_TOP,
   WO_KEEP_AT_BOTTOM,
   WO_OMNIPRESENT
  };

static const char *const menu_options_entries[] = {
                                                   [WO_KEEP_ON_TOP]    = N_("Keep on top"),
                                                   [WO_KEEP_AT_BOTTOM] = N_("Keep at bottom"),
                                                   [WO_OMNIPRESENT]    = N_("Omnipresent")
};

/*
 * Defines the menu entries for the Other maximization sub-menu
 */
static const struct {
  const char *label;
  unsigned int shortcut_idx;
  int maxim_direction;
} menu_maximize_entries[] = {
                             { N_("All Directions"), WKBD_MAXIMIZE, MAX_VERTICAL | MAX_HORIZONTAL },
                             { N_("Vertically"), WKBD_VMAXIMIZE, MAX_VERTICAL },
                             { N_("Horizontally"), WKBD_HMAXIMIZE, MAX_HORIZONTAL },
                             { N_("Left Half"), WKBD_LHMAXIMIZE, MAX_VERTICAL | MAX_LEFTHALF },
                             { N_("Right Half"), WKBD_RHMAXIMIZE, MAX_VERTICAL | MAX_RIGHTHALF },
                             { N_("Top Half"), WKBD_THMAXIMIZE, MAX_HORIZONTAL | MAX_TOPHALF },
                             { N_("Bottom Half"), WKBD_BHMAXIMIZE, MAX_HORIZONTAL | MAX_BOTTOMHALF },
                             { N_("Left Top Corner"), WKBD_LTCMAXIMIZE, MAX_LEFTHALF | MAX_TOPHALF },
                             { N_("Right Top Corner"), WKBD_RTCMAXIMIZE, MAX_RIGHTHALF | MAX_TOPHALF },
                             { N_("Left Bottom Corner"), WKBD_LBCMAXIMIZE, MAX_LEFTHALF | MAX_BOTTOMHALF },
                             { N_("Right Bottom Corner"), WKBD_RBCMAXIMIZE, MAX_RIGHTHALF | MAX_BOTTOMHALF },
                             { N_("Tiled"), WKBD_MAXIMUS, MAX_MAXIMUS }
};

static void updateOptionsMenu(WMenu * menu, WWindow * wwin);

static void execWindowOptionCommand(WMenu * menu, WMenuEntry * entry)
{
  WWindow *wwin = (WWindow *) entry->clientdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

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

static void execMaximizeCommand(WMenu * menu, WMenuEntry * entry)
{
  WWindow *wwin = (WWindow *) entry->clientdata;
	
  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  handleMaximize(wwin, menu_maximize_entries[entry->order].maxim_direction);
}

static void updateUnmaximizeShortcut(WMenuEntry * entry, int flags)
{
  int key;

  switch (flags & (MAX_HORIZONTAL | MAX_VERTICAL | MAX_LEFTHALF | MAX_RIGHTHALF | MAX_TOPHALF | MAX_BOTTOMHALF | MAX_MAXIMUS)) {
  case MAX_HORIZONTAL:
    key = WKBD_HMAXIMIZE;
    break;

  case MAX_VERTICAL:
    key = WKBD_VMAXIMIZE;
    break;

  case MAX_LEFTHALF | MAX_VERTICAL:
    key = WKBD_LHMAXIMIZE;
    break;

  case MAX_RIGHTHALF | MAX_VERTICAL:
    key = WKBD_RHMAXIMIZE;
    break;

  case MAX_TOPHALF | MAX_HORIZONTAL:
    key = WKBD_THMAXIMIZE;
    break;

  case MAX_BOTTOMHALF | MAX_HORIZONTAL:
    key = WKBD_BHMAXIMIZE;
    break;

  case MAX_LEFTHALF | MAX_TOPHALF:
    key = WKBD_LTCMAXIMIZE;
    break;

  case MAX_RIGHTHALF | MAX_TOPHALF:
    key = WKBD_RTCMAXIMIZE;
    break;

  case MAX_LEFTHALF | MAX_BOTTOMHALF:
    key = WKBD_LBCMAXIMIZE;
    break;

  case MAX_RIGHTHALF | MAX_BOTTOMHALF:
    key = WKBD_RBCMAXIMIZE;
    break;

  case MAX_MAXIMUS:
    key = WKBD_MAXIMUS;
    break;

  default:
    key = WKBD_MAXIMIZE;
    break;
  }

  entry->rtext = GetShortcutKey(wKeyBindings[key]);
}

static void execMenuCommand(WMenu * menu, WMenuEntry * entry)
{
  WWindow *wwin = (WWindow *) entry->clientdata;
  WApplication *wapp;

  CloseWindowMenu(menu->frame->screen_ptr);

  switch (entry->order) {
  case MC_CLOSE:
    /* send delete message */
    wClientSendProtocol(wwin, w_global.atom.wm.delete_window,
                        w_global.timestamp.last_event);
    break;

  case MC_KILL:
    wretain(wwin);
    if (wPreferences.dont_confirm_kill
        || WSRunAlertPanel(_("Kill Application"),
                           _("This will kill the application.\n"
                             "Any unsaved changes will be lost.\nPlease confirm."),
                           _("Yes"), _("No"), NULL) == WAPRDefault) {
      if (!wwin->flags.destroyed)
        wClientKill(wwin);
    }
    wrelease(wwin);
    break;

  case MC_MINIATURIZE:
    if (wwin->flags.miniaturized) {
      wDeiconifyWindow(wwin);
    } else {
      if (wwin->protocols.MINIATURIZE_WINDOW) {
        wClientSendProtocol(wwin, w_global.atom.gnustep.wm_miniaturize_window,
                            w_global.timestamp.last_event);
      } else {
        wIconifyWindow(wwin);
      }
    }
    break;

  case MC_MAXIMIZE:
    if (wwin->flags.maximized)
      wUnmaximizeWindow(wwin);
    else
      wMaximizeWindow(wwin, MAX_VERTICAL | MAX_HORIZONTAL);
    break;

  case MC_SHADE:
    if (wwin->flags.shaded)
      wUnshadeWindow(wwin);
    else
      wShadeWindow(wwin);
    break;

  case MC_SELECT:
    if (!wwin->flags.miniaturized)
      wSelectWindow(wwin, !wwin->flags.selected);
    else
      wIconSelect(wwin->icon);
    break;

  case MC_MOVERESIZE:
    wKeyboardMoveResizeWindow(wwin);
    break;

  case MC_RELAUNCH:
    (void) RelaunchWindow(wwin);
    break;

  case MC_HIDE:
    wapp = wApplicationOf(wwin->main_window);
    wHideApplication(wapp);
    break;
  }
}

static void switchWSCommand(WMenu * menu, WMenuEntry * entry)
{
  WWindow *wwin = (WWindow *) entry->clientdata;

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  wSelectWindow(wwin, False);
  wWindowChangeWorkspace(wwin, entry->order);
}

static void makeShortcutCommand(WMenu * menu, WMenuEntry * entry)
{
  WWindow *wwin = (WWindow *) entry->clientdata;
  WScreen *scr = wwin->screen_ptr;
  int index = entry->order - wlengthof(menu_options_entries);

  /* Parameter not used, but tell the compiler that it is ok */
  (void) menu;

  if (scr->shortcutWindows[index]) {
    WMFreeArray(scr->shortcutWindows[index]);
    scr->shortcutWindows[index] = NULL;
  }

  if (wwin->flags.selected && scr->selected_windows) {
    scr->shortcutWindows[index] = WMDuplicateArray(scr->selected_windows);
    /*WMRemoveFromArray(scr->shortcutWindows[index], wwin);
      WMInsertInArray(scr->shortcutWindows[index], 0, wwin); */
  } else {
    scr->shortcutWindows[index] = WMCreateArray(4);
    WMAddToArray(scr->shortcutWindows[index], wwin);
  }

  wSelectWindow(wwin, !wwin->flags.selected);
  XFlush(dpy);
  wusleep(3000);
  wSelectWindow(wwin, !wwin->flags.selected);
  XFlush(dpy);
}


static void updateWorkspaceMenu(WMenu * menu)
{
  WScreen *scr = menu->frame->screen_ptr;
  char title[MAX_WORKSPACENAME_WIDTH + 1];
  WMenuEntry *entry;
  int i;

  for (i = 0; i < scr->workspace_count; i++) {
    if (i < menu->entry_no) {

      entry = menu->entries[i];
      if (strcmp(entry->text, scr->workspaces[i]->name) != 0) {
        wfree(entry->text);
        strncpy(title, scr->workspaces[i]->name, MAX_WORKSPACENAME_WIDTH);
        title[MAX_WORKSPACENAME_WIDTH] = 0;
        menu->entries[i]->text = wstrdup(title);
        menu->entries[i]->rtext = GetShortcutKey(wKeyBindings[WKBD_MOVE_WORKSPACE1 + i]);
        menu->flags.realized = 0;
      }
    } else {
      strncpy(title, scr->workspaces[i]->name, MAX_WORKSPACENAME_WIDTH);
      title[MAX_WORKSPACENAME_WIDTH] = 0;

      entry = wMenuAddCallback(menu, title, switchWSCommand, NULL);
      entry->rtext = GetShortcutKey(wKeyBindings[WKBD_MOVE_WORKSPACE1 + i]);

      menu->flags.realized = 0;
    }

    /* workspace shortcut labels */
    if (i / 10 == scr->current_workspace / 10)
      entry->rtext = GetShortcutKey(wKeyBindings[WKBD_MOVE_WORKSPACE1 + (i % 10)]);
    else
      entry->rtext = NULL;
  }

  if (!menu->flags.realized)
    wMenuRealize(menu);
}

static void updateMakeShortcutMenu(WMenu * menu, WWindow * wwin)
{
  WMenu *smenu = menu->cascades[menu->entries[MC_OPTIONS]->cascade];
  int i;
  char *buffer;
  int buflen;
  KeyCode kcode;

  if (!smenu)
    return;

  buflen = strlen(_("Set Shortcut")) + 16;
  buffer = wmalloc(buflen);

  for (i = wlengthof(menu_options_entries); i < smenu->entry_no; i++) {
    int shortcutNo = i - wlengthof(menu_options_entries);
    WMenuEntry *entry = smenu->entries[i];
    WMArray *shortSelWindows = wwin->screen_ptr->shortcutWindows[shortcutNo];

    snprintf(buffer, buflen, "%s %i", _("Set Shortcut"), shortcutNo + 1);

    if (!shortSelWindows) {
      entry->flags.indicator_on = 0;
    } else {
      entry->flags.indicator_on = 1;
      if (WMCountInArray(shortSelWindows, wwin))
        entry->flags.indicator_type = MI_DIAMOND;
      else
        entry->flags.indicator_type = MI_CHECK;
    }

    if (strcmp(buffer, entry->text) != 0) {
      wfree(entry->text);
      entry->text = wstrdup(buffer);
      smenu->flags.realized = 0;
    }

    kcode = wKeyBindings[WKBD_WINDOW1 + shortcutNo].keycode;

    if (kcode) {
      char *tmp;

      tmp = GetShortcutKey(wKeyBindings[WKBD_WINDOW1 + shortcutNo]);
      if (tmp == NULL) {
        if (entry->rtext != NULL) {
          /* There was a shortcut, but there is no more */
          wfree(entry->rtext);
          entry->rtext = NULL;
          smenu->flags.realized = 0;
        }
      } else if (entry->rtext == NULL) {
        /* There was no shortcut, but there is one now */
        entry->rtext = tmp;
        smenu->flags.realized = 0;
      } else if (strcmp(tmp, entry->rtext) != 0) {
        /* There was a shortcut, but it has changed */
        wfree(entry->rtext);
        entry->rtext = tmp;
        smenu->flags.realized = 0;
      } else {
        /* There was a shortcut but it did not change */
        wfree(tmp);
      }
      wMenuSetEnabled(smenu, i, True);
    } else {
      wMenuSetEnabled(smenu, i, False);
      if (entry->rtext) {
        wfree(entry->rtext);
        entry->rtext = NULL;
        smenu->flags.realized = 0;
      }
    }
    entry->clientdata = wwin;
  }
  wfree(buffer);
  if (!smenu->flags.realized)
    wMenuRealize(smenu);
}

static void updateOptionsMenu(WMenu * menu, WWindow * wwin)
{
  WMenu *smenu = menu->cascades[menu->entries[MC_OPTIONS]->cascade];

  /* keep on top check */
  smenu->entries[WO_KEEP_ON_TOP]->clientdata = wwin;
  smenu->entries[WO_KEEP_ON_TOP]->flags.indicator_on =
    (wwin->frame->core->stacking->window_level == NSFloatingWindowLevel) ? 1 : 0;
  wMenuSetEnabled(smenu, WO_KEEP_ON_TOP, !wwin->flags.miniaturized);

  /* keep at bottom check */
  smenu->entries[WO_KEEP_AT_BOTTOM]->clientdata = wwin;
  smenu->entries[WO_KEEP_AT_BOTTOM]->flags.indicator_on =
    (wwin->frame->core->stacking->window_level == NSSunkenWindowLevel) ? 1 : 0;
  wMenuSetEnabled(smenu, WO_KEEP_AT_BOTTOM, !wwin->flags.miniaturized);

  /* omnipresent check */
  smenu->entries[WO_OMNIPRESENT]->clientdata = wwin;
  smenu->entries[WO_OMNIPRESENT]->flags.indicator_on = IS_OMNIPRESENT(wwin);

  smenu->flags.realized = 0;
  wMenuRealize(smenu);
}

static void updateMaximizeMenu(WMenu * menu, WWindow * wwin)
{
  WMenu *smenu = menu->cascades[menu->entries[MC_OTHERMAX]->cascade];
  int i;

  for (i = 0; i < smenu->entry_no; i++) {
    smenu->entries[i]->clientdata = wwin;
    smenu->entries[i]->rtext = GetShortcutKey(wKeyBindings[menu_maximize_entries[i].shortcut_idx]);
  }

  smenu->flags.realized = 0;
  wMenuRealize(smenu);
}

static WMenu *makeWorkspaceMenu(WScreen * scr)
{
  WMenu *menu;

  menu = wMenuCreate(scr, NULL, False);
  if (!menu) {
    wwarning(_("could not create submenu for window menu"));
    return NULL;
  }

  updateWorkspaceMenu(menu);

  /*
   * The Workspace Menu is made visible in the screen structure because
   * it is updated when there is a change on workspaces. This was done
   * to be efficient, avoiding re-generating completely the window menu
   * and its sub-menus everytime it is needed.
   */
  scr->workspace_submenu = menu;

  return menu;
}

static WMenu *makeOptionsMenu(WScreen * scr)
{
  WMenu *menu;
  WMenuEntry *entry;
  int i;

  menu = wMenuCreate(scr, NULL, False);
  if (!menu) {
    wwarning(_("could not create submenu for window menu"));
    return NULL;
  }

  for (i = 0; i < wlengthof(menu_options_entries); i++) {
    entry = wMenuAddCallback(menu, _(menu_options_entries[i]), execWindowOptionCommand, NULL);
    entry->flags.indicator = 1;
    entry->flags.indicator_type = MI_CHECK;
  }

  for (i = 0; i < MAX_WINDOW_SHORTCUTS; i++) {
    entry = wMenuAddCallback(menu, "", makeShortcutCommand, NULL);
    entry->flags.indicator = 1;
  }

  return menu;
}

static WMenu *makeMaximizeMenu(WScreen * scr)
{
  WMenu *menu;
  int i;

  menu = wMenuCreate(scr, NULL, False);
  if (!menu) {
    wwarning(_("could not create submenu for window menu"));
    return NULL;
  }

  for (i = 0; i < wlengthof(menu_maximize_entries); i++)
    wMenuAddCallback(menu, _(menu_maximize_entries[i].label), execMaximizeCommand, NULL);

  return menu;
}

static WMenu *createWindowMenu(WScreen * scr)
{
  WMenu *menu;
  int i;

  menu = wMenuCreate(scr, NULL, False);

  for (i = 0; i < wlengthof(window_menu_entries); i++) {
    WMenuEntry *entry;

    if (window_menu_entries[i].label != NULL)
      entry = wMenuAddCallback(menu, _(window_menu_entries[i].label),
                               (window_menu_entries[i].generate_submenu == NULL)?execMenuCommand:NULL,
                               NULL);
    if (window_menu_entries[i].generate_submenu != NULL) {
      WMenu *submenu;

      submenu = window_menu_entries[i].generate_submenu(scr);
      wMenuEntrySetCascade(menu, entry, submenu);
    }
  }

  return menu;
}

void CloseWindowMenu(WScreen * scr)
{
  if (scr->window_menu) {
    if (scr->window_menu->flags.mapped)
      wMenuUnmap(scr->window_menu);

    if (scr->window_menu->entries[0]->clientdata) {
      WWindow *wwin = (WWindow *) scr->window_menu->entries[0]->clientdata;

      wwin->flags.menu_open_for_me = 0;
    }
    scr->window_menu->entries[0]->clientdata = NULL;
  }
}

static void updateMenuForWindow(WMenu * menu, WWindow * wwin)
{
  WApplication *wapp = wApplicationOf(wwin->main_window);
  WScreen *scr = wwin->screen_ptr;
  int i;

  updateOptionsMenu(menu, wwin);
  updateMaximizeMenu(menu, wwin);

  updateMakeShortcutMenu(menu, wwin);

  if (menu->entries[MC_MINIATURIZE])
    wMenuSetEnabled(menu, MC_HIDE, wapp != NULL && !WFLAGP(wapp->main_window_desc, no_appicon));

  if (menu->entries[MC_CLOSE])
    wMenuSetEnabled(menu, MC_CLOSE, (wwin->protocols.DELETE_WINDOW && !WFLAGP(wwin, no_closable)));

  if (menu->entries[MC_MINIATURIZE]) {
    if (wwin->flags.miniaturized) {
      static char *text = NULL;
      if (!text)
        text = _("Deminiaturize");

      menu->entries[MC_MINIATURIZE]->text = text;
    } else {
      static char *text = NULL;
      if (!text)
        text = _("Miniaturize");

      menu->entries[MC_MINIATURIZE]->text = text;
    }
    wMenuSetEnabled(menu, MC_MINIATURIZE, !WFLAGP(wwin, no_miniaturizable));
    menu->entries[MC_MINIATURIZE]->rtext = GetShortcutKey(wKeyBindings[WKBD_MINIATURIZE]);
  }

  if (menu->entries[MC_MAXIMIZE]) {
    if (wwin->flags.maximized) {
      static char *text = NULL;
      if (!text)
        text = _("Unmaximize");

      menu->entries[MC_MAXIMIZE]->text = text;
      updateUnmaximizeShortcut(menu->entries[MC_MAXIMIZE], wwin->flags.maximized);
    } else {
      static char *text = NULL;
      if (!text)
        text = _("Maximize");

      menu->entries[MC_MAXIMIZE]->text = text;
      menu->entries[MC_MAXIMIZE]->rtext = GetShortcutKey(wKeyBindings[WKBD_MAXIMIZE]);
    }
    wMenuSetEnabled(menu, MC_MAXIMIZE, IS_RESIZABLE(wwin));
  }

  wMenuSetEnabled(menu, MC_MOVERESIZE, IS_RESIZABLE(wwin)
                  && !wwin->flags.miniaturized);

  if (wwin->flags.shaded) {
    static char *text = NULL;
    if (!text)
      text = _("Unshade");

    menu->entries[MC_SHADE]->text = text;
  } else {
    static char *text = NULL;
    if (!text)
      text = _("Shade");

    menu->entries[MC_SHADE]->text = text;
  }

  wMenuSetEnabled(menu, MC_SHADE, !WFLAGP(wwin, no_shadeable)	&& !wwin->flags.miniaturized);

  if (wwin->flags.selected) {
    static char *text = NULL;
    if (!text)
      text = _("Deselect");

    menu->entries[MC_SELECT]->text = text;
  } else {
    static char *text = NULL;
    if (!text)
      text = _("Select");

    menu->entries[MC_SELECT]->text = text;
  }

  wMenuSetEnabled(menu, MC_CHANGEWKSPC, !IS_OMNIPRESENT(wwin));

  /* Update shortcut labels except for (Un)Maximize which is
   * handled separately.
   */
  if (menu->entries[MC_SHADE])
    menu->entries[MC_SHADE]->rtext = GetShortcutKey(wKeyBindings[WKBD_SHADE]);
  if (menu->entries[MC_HIDE])
    menu->entries[MC_HIDE]->rtext = GetShortcutKey(wKeyBindings[WKBD_HIDE]);
  if (menu->entries[MC_MOVERESIZE])
    menu->entries[MC_MOVERESIZE]->rtext = GetShortcutKey(wKeyBindings[WKBD_MOVERESIZE]);
  if (menu->entries[MC_SELECT])
    menu->entries[MC_SELECT]->rtext = GetShortcutKey(wKeyBindings[WKBD_SELECT]);
  if (menu->entries[MC_RELAUNCH])
    menu->entries[MC_RELAUNCH]->rtext = GetShortcutKey(wKeyBindings[WKBD_RELAUNCH]);
  if (menu->entries[MC_CLOSE])
    menu->entries[MC_CLOSE]->rtext = GetShortcutKey(wKeyBindings[WKBD_CLOSE]);

  /* set the client data of the entries to the window */
  for (i = 0; i < menu->entry_no; i++) {
    menu->entries[i]->clientdata = wwin;
  }

  for (i = 0; i < scr->workspace_submenu->entry_no; i++) {
    scr->workspace_submenu->entries[i]->clientdata = wwin;
    if (i == scr->current_workspace)
      wMenuSetEnabled(scr->workspace_submenu, i, False);
    else
      wMenuSetEnabled(scr->workspace_submenu, i, True);
  }

  menu->flags.realized = 0;
  wMenuRealize(menu);
}

static WMenu *open_window_menu_core(WWindow *wwin)
{
  WScreen *scr = wwin->screen_ptr;
  WMenu *menu;

  wwin->flags.menu_open_for_me = 1;

  if (!scr->window_menu) {
    scr->window_menu = createWindowMenu(scr);

    /* hack to save some memory allocation/deallocation */
    if (scr->window_menu->entries[MC_MINIATURIZE])
      wfree(scr->window_menu->entries[MC_MINIATURIZE]->text);
    if (scr->window_menu->entries[MC_MAXIMIZE])
      wfree(scr->window_menu->entries[MC_MAXIMIZE]->text);
    if (scr->window_menu->entries[MC_SHADE])
      wfree(scr->window_menu->entries[MC_SHADE]->text);
    if (scr->window_menu->entries[MC_SELECT])
      wfree(scr->window_menu->entries[MC_SELECT]->text);
  } else {
    updateWorkspaceMenu(scr->workspace_submenu);
  }

  menu = scr->window_menu;
  if (menu->flags.mapped) {
    wMenuUnmap(menu);
    if (menu->entries[0]->clientdata == wwin)
      return NULL;
  }

  updateMenuForWindow(menu, wwin);

  return menu;
}

static void prepare_menu_position(WMenu *menu, int *x, int *y)
{
  WMRect rect;

  rect = wGetRectForHead(menu->frame->screen_ptr,
                         wGetHeadForPointerLocation(menu->frame->screen_ptr));
  if (*x < rect.pos.x - menu->frame->core->width / 2)
    *x = rect.pos.x - menu->frame->core->width / 2;
  if (*y < rect.pos.y)
    *y = rect.pos.y;
}

void OpenWindowMenu(WWindow *wwin, int x, int y, int keyboard)
{
  WMenu *menu;

  menu = open_window_menu_core(wwin);
  if (!menu)
    return;

  /* Specific menu position */
  x -= menu->frame->core->width / 2;
  if (x + menu->frame->core->width > wwin->frame_x + wwin->frame->core->width)
    x = wwin->frame_x + wwin->frame->core->width - menu->frame->core->width;
  if (x < wwin->frame_x)
    x = wwin->frame_x;

  /* Common menu position */
  prepare_menu_position(menu, &x, &y);

  if (!wwin->flags.internal_window)
    wMenuMapAt(menu, x, y, keyboard);
}

void OpenWindowMenu2(WWindow *wwin, int x, int y, int keyboard)
{
  int i;
  WMenu *menu;
  WScreen *scr = wwin->screen_ptr;

  menu = open_window_menu_core(wwin);
  if (!menu)
    return;

  /* Specific menu position */
  for (i = 0; i < scr->workspace_submenu->entry_no; i++) {
    scr->workspace_submenu->entries[i]->clientdata = wwin;
    wMenuSetEnabled(scr->workspace_submenu, i, True);
  }

  x -= menu->frame->core->width / 2;

  /* Common menu position */
  prepare_menu_position(menu, &x, &y);

  if (!wwin->flags.internal_window)
    wMenuMapAt(menu, x, y, keyboard);
}

void OpenMiniwindowMenu(WWindow * wwin, int x, int y)
{
  WMenu *menu;

  menu = open_window_menu_core(wwin);
  if (!menu)
    return;

  x -= menu->frame->core->width / 2;

  wMenuMapAt(menu, x, y, False);
}

void DestroyWindowMenu(WScreen *scr)
{
  if (scr->window_menu) {
    scr->window_menu->entries[MC_MINIATURIZE]->text = NULL;
    scr->window_menu->entries[MC_MAXIMIZE]->text = NULL;
    scr->window_menu->entries[MC_SHADE]->text = NULL;
    scr->window_menu->entries[MC_SELECT]->text = NULL;
    wMenuDestroy(scr->window_menu, True);
    scr->window_menu = NULL;
  }
}
