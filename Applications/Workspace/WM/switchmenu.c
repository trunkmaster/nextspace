/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997      Shige Abe
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

#include "WM.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <CoreFoundation/CFNumber.h>

#include <core/util.h>

#include "WM.h"
#include "window.h"
#include "actions.h"
#include "client.h"
#include "misc.h"
#include "stacking.h"
#include "workspace.h"
#include "framewin.h"
#include "switchmenu.h"

/* Maximum width of window title in window list */
#define MAX_WINDOWLIST_WIDTH	400

/* switchmenu actions */
#define ACTION_ADD		0
#define ACTION_REMOVE		1
#define ACTION_CHANGE		2
#define ACTION_CHANGE_WORKSPACE	3
#define ACTION_CHANGE_STATE	4

#define IS_GNUSTEP_MENU(w) ((w)->wm_gnustep_attr &&                     \
                            ((w)->wm_gnustep_attr->flags & GSWindowLevelAttr) && \
                            ((w)->wm_gnustep_attr->window_level == NSMainMenuWindowLevel || \
                             (w)->wm_gnustep_attr->window_level == NSSubmenuWindowLevel || \
                             (w)->wm_gnustep_attr->window_level == NSPopUpMenuWindowLevel))

static int initialized = 0;

static void windowObserver(CFNotificationCenterRef center,  void *observer,
                           CFNotificationName name, const void *window,
                           CFDictionaryRef userInfo);
static void workspaceObserver(CFNotificationCenterRef center, void *observer,
                              CFNotificationName name, const void *screen,
                              CFDictionaryRef userInfo);

/*
 * FocusWindow
 *
 *  - Needs to check if already in the right workspace before
 *    calling wChangeWorkspace?
 *
 *  Order:
 *    Switch to correct workspace
 *    Unshade if shaded
 *    If iconified then deiconify else focus/raise.
 */
static void focusWindow(WMenu *menu, WMenuEntry *entry)
{
  WWindow *wwin;

  wwin = (WWindow *) entry->clientdata;
  wWindowSingleFocus(wwin);
}

void InitializeSwitchMenu(WScreen *scr)
{
  if (!initialized) {
    WMenu *switchmenu = NULL;
    WWindow *wwin;

    switchmenu = wMenuCreate(scr, _("Windows"), False);
    scr->switch_menu = switchmenu;
    wretain(scr->switch_menu);

    wwin = scr->focused_window;
    while (wwin) {
      UpdateSwitchMenu(scr, wwin, ACTION_ADD);
      wwin = wwin->prev;
    }
    
    /* windows */
    CFNotificationCenterAddObserver(scr->notificationCenter, switchmenu, windowObserver,
                                    WMDidManageWindowNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(scr->notificationCenter, switchmenu, windowObserver,
                                    WMDidUnmanageWindowNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(scr->notificationCenter, switchmenu, windowObserver,
                                    WMDidChangeWindowWorkspaceNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(scr->notificationCenter, switchmenu, windowObserver,
                                    WMDidChangeWindowStateNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(scr->notificationCenter, switchmenu, windowObserver,
                                    WMDidChangeWindowFocusNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(scr->notificationCenter, switchmenu, windowObserver,
                                    WMDidChangeWindowStackingNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(scr->notificationCenter, switchmenu, windowObserver,
                                    WMDidChangeWindowNameNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    /* workspaces */
    CFNotificationCenterAddObserver(scr->notificationCenter, switchmenu, workspaceObserver,
                                    WMDidChangeWorkspaceNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(scr->notificationCenter, switchmenu, workspaceObserver,
                                    WMDidChangeWorkspaceNameNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    
    initialized = 1;
  }
}

/* 
   Open switch menu
*/
void OpenSwitchMenu(WScreen *scr, int x, int y, int keyboard)
{
  WMenu *switchmenu = scr->switch_menu;
  /* WWindow *wwin; */

  if (switchmenu) {
    if (!switchmenu->flags.realized) {
      wMenuRealize(switchmenu);
    }
    if (switchmenu->flags.mapped) {
      if (!switchmenu->flags.buttoned) {
        wMenuUnmap(switchmenu);
      } else {
        wRaiseFrame(switchmenu->frame->core);
        if (keyboard)
          wMenuMapAt(switchmenu, 0, 0, True);
        else
          wMenuMapCopyAt(switchmenu, x - switchmenu->frame->core->width / 2, y);
      }
    } else {
      if (keyboard && x == scr->scr_width / 2 && y == scr->scr_height / 2) {
        y = y - switchmenu->frame->core->height / 2;
      }
      wMenuMapAt(switchmenu, x - switchmenu->frame->core->width / 2, y, keyboard);
    }
    return;
  }
}

static int menuIndexForWindow(WMenu *menu, WWindow *wwin, int old_pos)
{
  int idx;

  if (menu->entry_no <= old_pos)
    return -1;

#define WS(i)  ((WWindow*)menu->entries[i]->clientdata)->frame->workspace
  if (old_pos >= 0) {
    if (WS(old_pos) >= wwin->frame->workspace
        && (old_pos == 0 || WS(old_pos - 1) <= wwin->frame->workspace)) {
      return old_pos;
    }
  }
#undef WS

  for (idx = 0; idx < menu->entry_no; idx++) {
    WWindow *tw = (WWindow *) menu->entries[idx]->clientdata;

    if (!IS_OMNIPRESENT(tw)
        && tw->frame->workspace > wwin->frame->workspace) {
      break;
    }
  }

  return idx;
}

/* 
   Update switch menu
*/
void UpdateSwitchMenu(WScreen *scr, WWindow *wwin, int action)
{
  WMenu *switchmenu = scr->switch_menu;
  WMenuEntry *entry;
  char title[MAX_MENU_TEXT_LENGTH + 6];
  int len = sizeof(title);
  int i;
  int checkVisibility = 0;

  if (!wwin->screen_ptr->switch_menu)
    return;
  /*
   *  This menu is updated under the following conditions:
   *
   *    1.  When a window is created.
   *    2.  When a window is destroyed.
   *
   *    3.  When a window changes it's title.
   *    4.  When a window changes its workspace.
   */
  if (action == ACTION_ADD) {
    char *t;
    int idx;

    if (wwin->flags.internal_window || WFLAGP(wwin, skip_window_list) || IS_GNUSTEP_MENU(wwin)) {
      return;
    }

    if (wwin->frame->title)
      snprintf(title, len, "%s", wwin->frame->title);
    else
      snprintf(title, len, "%s", DEF_WINDOW_TITLE);
    t = ShrinkString(scr->menu_entry_font, title, MAX_WINDOWLIST_WIDTH);

    if (IS_OMNIPRESENT(wwin))
      idx = -1;
    else {
      idx = menuIndexForWindow(switchmenu, wwin, -1);
    }

    entry = wMenuInsertCallback(switchmenu, idx, t, focusWindow, wwin);
    wfree(t);

    entry->flags.indicator = 1;
    entry->rtext = wmalloc(MAX_WORKSPACENAME_WIDTH + 8);
    if (IS_OMNIPRESENT(wwin))
      snprintf(entry->rtext, MAX_WORKSPACENAME_WIDTH, "[*]");
    else
      snprintf(entry->rtext, MAX_WORKSPACENAME_WIDTH, "[%s]",
               scr->workspaces[wwin->frame->workspace]->name);

    if (wwin->flags.hidden) {
      entry->flags.indicator_type = MI_HIDDEN;
      entry->flags.indicator_on = 1;
    } else if (wwin->flags.miniaturized) {
      entry->flags.indicator_type = MI_MINIWINDOW;
      entry->flags.indicator_on = 1;
    } else if (wwin->flags.focused) {
      entry->flags.indicator_type = MI_DIAMOND;
      entry->flags.indicator_on = 1;
    } else if (wwin->flags.shaded) {
      entry->flags.indicator_type = MI_SHADED;
      entry->flags.indicator_on = 1;
    }

    wMenuRealize(switchmenu);
    checkVisibility = 1;
  } else {
    char *t;
    for (i = 0; i < switchmenu->entry_no; i++) {
      entry = switchmenu->entries[i];
      /* this is the entry that was changed */
      if (entry->clientdata == wwin) {
        switch (action) {
        case ACTION_REMOVE:
          wMenuRemoveItem(switchmenu, i);
          wMenuRealize(switchmenu);
          checkVisibility = 1;
          break;

        case ACTION_CHANGE:
          if (entry->text)
            wfree(entry->text);

          if (wwin->frame->title)
            snprintf(title, MAX_MENU_TEXT_LENGTH, "%s", wwin->frame->title);
          else
            snprintf(title, MAX_MENU_TEXT_LENGTH, "%s", DEF_WINDOW_TITLE);

          t = ShrinkString(scr->menu_entry_font, title, MAX_WINDOWLIST_WIDTH);
          entry->text = t;

          wMenuRealize(switchmenu);
          checkVisibility = 1;
          break;

        case ACTION_CHANGE_WORKSPACE:
          if (entry->rtext) {
            int idx = -1;
            char *t, *rt;
            int it, ion;

            if (IS_OMNIPRESENT(wwin)) {
              snprintf(entry->rtext, MAX_WORKSPACENAME_WIDTH, "[*]");
            } else {
              snprintf(entry->rtext, MAX_WORKSPACENAME_WIDTH,
                       "[%s]",
                       scr->workspaces[wwin->frame->workspace]->name);
            }

            rt = entry->rtext;
            entry->rtext = NULL;
            t = entry->text;
            entry->text = NULL;

            it = entry->flags.indicator_type;
            ion = entry->flags.indicator_on;

            if (!IS_OMNIPRESENT(wwin) && idx < 0) {
              idx = menuIndexForWindow(switchmenu, wwin, i);
            }

            wMenuRemoveItem(switchmenu, i);

            entry = wMenuInsertCallback(switchmenu, idx, t, focusWindow, wwin);
            wfree(t);
            entry->rtext = rt;
            entry->flags.indicator = 1;
            entry->flags.indicator_type = it;
            entry->flags.indicator_on = ion;
          }
          wMenuRealize(switchmenu);
          checkVisibility = 1;
          break;

        case ACTION_CHANGE_STATE:
          if (wwin->flags.hidden) {
            entry->flags.indicator_type = MI_HIDDEN;
            entry->flags.indicator_on = 1;
          } else if (wwin->flags.miniaturized) {
            entry->flags.indicator_type = MI_MINIWINDOW;
            entry->flags.indicator_on = 1;
          } else if (wwin->flags.shaded && !wwin->flags.focused) {
            entry->flags.indicator_type = MI_SHADED;
            entry->flags.indicator_on = 1;
          } else {
            entry->flags.indicator_on = wwin->flags.focused;
            entry->flags.indicator_type = MI_DIAMOND;
          }
          break;
        }
        break;
      }
    }
  }
  if (checkVisibility) {
    int tmp;

    tmp = switchmenu->frame->top_width + 5;
    /* if menu got unreachable, bring it to a visible place */
    if (switchmenu->frame_x < tmp - (int)switchmenu->frame->core->width) {
      wMenuMove(switchmenu, tmp - (int)switchmenu->frame->core->width,
                switchmenu->frame_y, False);
    }
  }
  wMenuPaint(switchmenu);
}

static void UpdateSwitchMenuWorkspace(WScreen *scr, int workspace)
{
  WMenu *menu = scr->switch_menu;
  WWindow *wwin;

  if (!menu)
    return;

  for (int i = 0; i < menu->entry_no; i++) {
    wwin = (WWindow *) menu->entries[i]->clientdata;

    if (wwin->frame->workspace == workspace && !IS_OMNIPRESENT(wwin)) {
      if (IS_OMNIPRESENT(wwin))
        snprintf(menu->entries[i]->rtext, MAX_WORKSPACENAME_WIDTH, "[*]");
      else
        snprintf(menu->entries[i]->rtext, MAX_WORKSPACENAME_WIDTH, "[%s]",
                 scr->workspaces[wwin->frame->workspace]->name);
      menu->flags.realized = 0;
    }
  }
  if (!menu->flags.realized)
    wMenuRealize(menu);
}

/* 
   Notifications 
*/
static void windowObserver(CFNotificationCenterRef center,
                           void *observer,
                           CFNotificationName name,
                           const void *window,
                           CFDictionaryRef userInfo)
{
  WWindow *wwin = (WWindow *)window;
    
  if (!wwin)
    return;
  
  if (CFStringCompare(name, WMDidManageWindowNotification, 0) == 0) {
    UpdateSwitchMenu(wwin->screen_ptr, wwin, ACTION_ADD);
  }
  else if (CFStringCompare(name, WMDidUnmanageWindowNotification, 0) == 0) {
    UpdateSwitchMenu(wwin->screen_ptr, wwin, ACTION_REMOVE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowWorkspaceNotification, 0) == 0) {
    UpdateSwitchMenu(wwin->screen_ptr, wwin, ACTION_CHANGE_WORKSPACE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowFocusNotification, 0) == 0) {
    UpdateSwitchMenu(wwin->screen_ptr, wwin, ACTION_CHANGE_STATE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowNameNotification, 0) == 0) {
    UpdateSwitchMenu(wwin->screen_ptr, wwin, ACTION_CHANGE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowStateNotification, 0) == 0) {
    CFStringRef wstate = (CFStringRef)wGetNotificationInfoValue(userInfo, CFSTR("state"));
    if (CFStringCompare(wstate, CFSTR("omnipresent"), 0) == 0) {
      UpdateSwitchMenu(wwin->screen_ptr, wwin, ACTION_CHANGE_WORKSPACE);
    }
    else {
      UpdateSwitchMenu(wwin->screen_ptr, wwin, ACTION_CHANGE_STATE);
    }
  }
}

static void workspaceObserver(CFNotificationCenterRef center,
                              void *observer,
                              CFNotificationName name,
                              const void *screen,
                              CFDictionaryRef userInfo)
{
  WScreen *scr = (WScreen *)screen;
  CFNumberRef ws = (CFNumberRef)wGetNotificationInfoValue(userInfo, CFSTR("workspace"));
  int workspace;
  
  CFNumberGetValue(ws, kCFNumberShortType, &workspace);

  if (CFStringCompare(name, WMDidChangeWorkspaceNameNotification, 0) == 0) {
    UpdateSwitchMenuWorkspace(scr, workspace);
  }
  else if (CFStringCompare(name, WMDidChangeWorkspaceNotification, 0) == 0) {
    
  }
}
