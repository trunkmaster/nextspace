#include <string.h>
#include <stdio.h>

#include <core/log_utils.h>
#include <core/string_utils.h>

#include "appmenu.h"
#include "window.h"
#include "client.h"
#include "framewin.h"
#include "actions.h"
#include "misc.h"
#include "desktop.h"
#include "dock.h"
#include "iconyard.h"

static CFStringRef WMenuPath = CFSTR("Path");
static CFStringRef WMenuType = CFSTR("Type");
static CFStringRef WMenuPositionX = CFSTR("X");
static CFStringRef WMenuPositionY = CFSTR("Y");
static CFStringRef WMenuTypeMain = CFSTR("Main");
static CFStringRef WMenuTypeTornOff = CFSTR("TornOff");
static CFStringRef WMenuTypeAttached = CFSTR("Attached");

// Main application menu
//-------------------------------------------------------------------------------------------------
static void mainCallback(WMenu *menu, WMenuItem *entry)
{
  WApplication *wapp = (WApplication *)entry->clientdata;
  
  if (!strcmp(entry->text, "Hide")) {
    if (wapp && !WFLAGP(wapp->main_wwin, no_appicon)) {
      wApplicationHide(wapp);
    }
  } else if (!strcmp(entry->text, "Hide Others")) {
    wApplicationHideOthers(wapp->last_focused);
  } else if (!strcmp(entry->text, "Quit")) {
    wApplicationQuit(wapp, False);
  } else if (!strcmp(entry->text, "Force Quit")) {
    wApplicationQuit(wapp, True);
  }
}

// "Windows" menu
//-------------------------------------------------------------------------------------------------

//---- "Windows" item actions ---
#define MAX_WINDOWLIST_WIDTH  400
#define ACTION_ADD            0
#define ACTION_REMOVE         1
#define ACTION_CHANGE         2
#define ACTION_CHANGE_DESKTOP 3
#define ACTION_CHANGE_STATE   4

#define ISMAPPED(w) ((w) && !(w)->flags.miniaturized && ((w)->flags.mapped || (w)->flags.shaded))
#define ISFOCUSED(w) ((w) && (w)->flags.focused)

static void _focusWindow(WMenu *menu, WMenuItem *entry)
{
  WWindow *wwin = (WWindow *)entry->clientdata;
  wWindowSingleFocus(wwin);
}

static void _miniaturizeWindow(WMenu *menu, WMenuItem *entry)
{
  WScreen *scr = menu->frame->screen_ptr;
  WWindow *wwin = scr->focused_window;
  Time event_time = entry->clientdata ? ((XEvent *)entry->clientdata)->xkey.time : CurrentTime;

  if (ISMAPPED(wwin) && ISFOCUSED(wwin) && !WFLAGP(wwin, no_miniaturizable)) {
    if (wwin->protocols.MINIATURIZE_WINDOW) {
      wClientSendProtocol(wwin, w_global.atom.gnustep.wm_miniaturize_window, event_time);
    } else {
      wIconifyWindow(wwin);
    }
  }

  // Do we need this option?
  /* WKBD_MINIMIZEALL: */
  /*   wHideAll(scr); */
  
  // clean used event info so it could be passed again
  entry->clientdata = NULL;
}

static void _shadeWindow(WMenu *menu, WMenuItem *entry)
{
  WWindow *wwin = menu->menu->screen_ptr->focused_window;
  
  if (!strcmp(entry->text, "Shade Window")) {
    wShadeWindow(wwin);
    wfree(entry->text);
    entry->text = wstrdup("Unshade Window");
  } else if (!strcmp(entry->text, "Unshade Window")) {
    wUnshadeWindow(wwin);
    wfree(entry->text);
    entry->text = wstrdup("Shade Window");
  }
}

static void _zoomWindow(WMenu *menu, WMenuItem *entry)
{
  WWindow *wwin = menu->menu->screen_ptr->focused_window;

  if (!strcmp(entry->text, "Zoom Window")) {
    wMaximizeWindow(wwin, MAX_MAXIMUS);
  } else if (!strcmp(entry->text, "Unzoom Window")) {
    wUnmaximizeWindow(wwin);
  }

  // Other variants of maximization - do need them?
  
  /* WKBD_MAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_VERTICAL | MAX_HORIZONTAL | MAX_KEYBOARD); */
  /*   } */
  /* WKBD_VMAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_VERTICAL | MAX_KEYBOARD); */
  /*   } */
  /* WKBD_HMAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_HORIZONTAL | MAX_KEYBOARD); */
  /*   } */
  /* WKBD_LHMAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_VERTICAL | MAX_LEFTHALF | MAX_KEYBOARD); */
  /*   } */
  /* WKBD_RHMAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_VERTICAL | MAX_RIGHTHALF | MAX_KEYBOARD); */
  /*   } */
  /* WKBD_THMAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_HORIZONTAL | MAX_TOPHALF | MAX_KEYBOARD); */
  /*   } */
  /* WKBD_BHMAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_HORIZONTAL | MAX_BOTTOMHALF | MAX_KEYBOARD); */
  /*   } */
  /* WKBD_LTCMAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_LEFTHALF | MAX_TOPHALF | MAX_KEYBOARD); */
  /*   } */
  /* WKBD_RTCMAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_RIGHTHALF | MAX_TOPHALF | MAX_KEYBOARD); */
  /*   } */
  /* WKBD_LBCMAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_LEFTHALF | MAX_BOTTOMHALF | MAX_KEYBOARD); */
  /*   } */
  /* WKBD_RBCMAXIMIZE: */
  /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) { */
  /*     handleMaximize(wwin, MAX_RIGHTHALF | MAX_BOTTOMHALF | MAX_KEYBOARD); */
  /*   } */
}
  
static void _closeWindow(WMenu *menu, WMenuItem *entry)
{
  WWindow *wwin = menu->frame->screen_ptr->focused_window;
  Time event_time = entry->clientdata ? ((XEvent *)entry->clientdata)->xkey.time : CurrentTime;

  if (ISMAPPED(wwin) && ISFOCUSED(wwin) && !WFLAGP(wwin, no_closable)) {
    if (wwin->protocols.DELETE_WINDOW) {
      wClientSendProtocol(wwin, w_global.atom.wm.delete_window, event_time);
    }
  }
  
  // clean used event info so it could be passed again
  entry->clientdata = NULL;
}

//---- "Windows" item actions end ---

static void _validateWindowsItems(WMenu *windows_menu, WWindow *wwin)
{
  WMenuItem *item;
  WWindow *focused_win = wwin->screen->focused_window;
  
  /* Update menu entries according to focused window state */
  if (focused_win->flags.shaded) {
    item = wMenuItemWithTitle(windows_menu, "Shade Window");
    if (item) {
      wfree(item->text);
      item->text = wstrdup("Unshade Window");
    }
  } else {
    item = wMenuItemWithTitle(windows_menu, "Unshade Window");
    if (item) {
      wfree(item->text);
      item->text = wstrdup("Shade Window");
    }
  }
  if (focused_win->flags.maximized) {
    item = wMenuItemWithTitle(windows_menu, "Zoom Window");
    if (item) {
      wfree(item->text);
      item->text = wstrdup("Unzoom Window");
    }
  } else {
    item = wMenuItemWithTitle(windows_menu, "Unzoom Window");
    if (item) {
      wfree(item->text);
      item->text = wstrdup("Zoom Window");
    }
  }

  /* Enable items applicable to focused window. Diable otherwise */
  item = wMenuItemWithTitle(windows_menu, "Miniaturize Window");
  wMenuItemSetEnabled(windows_menu, item, !WFLAGP(focused_win, no_miniaturizable) ? True : False);
  item = wMenuItemWithTitle(windows_menu, "Shade Window");
  wMenuItemSetEnabled(windows_menu, item, !WFLAGP(focused_win, no_titlebar) ? True : False);
  item = wMenuItemWithTitle(windows_menu, "Zoom Window");
  wMenuItemSetEnabled(windows_menu, item, IS_RESIZABLE(focused_win) ? True : False);
  item = wMenuItemWithTitle(windows_menu, "Close Window");
  wMenuItemSetEnabled(windows_menu, item, !WFLAGP(focused_win, no_closable) ? True : False);
}

static int _menuIndexForWindow(WMenu *menu, WWindow *wwin, int old_pos)
{
  int idx;

  if (menu->items_count <= old_pos)
    return -1;

#define WS(i)  ((WWindow*)menu->items[i]->clientdata)->frame->desktop
  if (old_pos >= 0) {
    if (WS(old_pos) >= wwin->frame->desktop
        && (old_pos == 0 || WS(old_pos - 1) <= wwin->frame->desktop)) {
      return old_pos;
    }
  }
#undef WS

  for (idx = 0; idx < menu->items_count; idx++) {
    WWindow *tw = (WWindow *)menu->items[idx]->clientdata;

    if (!tw || (!IS_OMNIPRESENT(tw) && tw->frame->desktop > wwin->frame->desktop)) {
      break;
    }
  }

  return idx;
}

static void _updateWindowsMenu(WMenu *windows_menu, WWindow *wwin, int action)
{
  WMenuItem *entry;
  char title[MAX_MENU_TEXT_LENGTH + 6];
  int len = sizeof(title);
  int i;
  int checkVisibility = 0;

  /*
   *  This menu is updated under the following conditions:
   *    1.  When a window is created.
   *    2.  When a window is destroyed.
   *    3.  When a window changes it's title.
   */
  if (action == ACTION_ADD) {
    char *t;
    int idx;

    if (wwin->flags.internal_window || WFLAGP(wwin, skip_window_list)) {
      return;
    }

    if (wwin->frame->title)
      snprintf(title, len, "%s", wwin->frame->title);
    else
      snprintf(title, len, "%s", DEF_WINDOW_TITLE);
    t = ShrinkString(wwin->screen->menu_item_font, title, MAX_WINDOWLIST_WIDTH);

    if (IS_OMNIPRESENT(wwin))
      idx = -1;
    else {
      idx = _menuIndexForWindow(windows_menu, wwin, -1);
    }

    entry = wMenuItemInsert(windows_menu, idx+1, t, _focusWindow, wwin);
    wfree(t);

    entry->flags.indicator = 1;
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
    if (windows_menu->selected_item_index >= 0) {
      windows_menu->selected_item_index++;
    }
    wMenuRealize(windows_menu);
    checkVisibility = 1;
  } else {
    char *t;
    for (i = 0; i < windows_menu->items_count; i++) {
      entry = windows_menu->items[i];
      /* this is the entry that was changed */
      if (entry->clientdata == wwin) {
        switch (action) {
        case ACTION_REMOVE:
          wMenuItemRemove(windows_menu, i);
          if (windows_menu->selected_item_index >= 0) {
            windows_menu->selected_item_index--;
          }
          wMenuRealize(windows_menu);
          checkVisibility = 1;
          break;

        case ACTION_CHANGE:
          if (entry->text)
            wfree(entry->text);

          if (wwin->frame->title)
            snprintf(title, MAX_MENU_TEXT_LENGTH, "%s", wwin->frame->title);
          else
            snprintf(title, MAX_MENU_TEXT_LENGTH, "%s", DEF_WINDOW_TITLE);

          t = ShrinkString(wwin->screen->menu_item_font, title, MAX_WINDOWLIST_WIDTH);
          entry->text = t;

          wMenuRealize(windows_menu);
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

    tmp = windows_menu->frame->top_width + 5;
    /* if menu got unreachable, bring it to a visible place */
    if (windows_menu->frame_x < tmp - (int)windows_menu->frame->core->width) {
      wMenuMove(windows_menu, tmp - (int)windows_menu->frame->core->width,
                windows_menu->frame_y, False);
    }
  }

  wMenuPaint(windows_menu);
}

static void _windowObserver(CFNotificationCenterRef center,
                           void *menu,
                           CFNotificationName name,
                           const void *window,
                           CFDictionaryRef userInfo)
{
  WMenu *windows_menu = (WMenu *)menu;
  WWindow *wwin = (WWindow *)window;

  if (!wwin || (wApplicationForWindow(wwin) != windows_menu->app)) {
    return;
  }
  
  if (CFStringCompare(name, WMDidManageWindowNotification, 0) == 0) {
    _updateWindowsMenu(windows_menu, wwin, ACTION_ADD);
  }
  else if (CFStringCompare(name, WMDidUnmanageWindowNotification, 0) == 0) {
    _updateWindowsMenu(windows_menu, wwin, ACTION_REMOVE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowFocusNotification, 0) == 0) {
    _updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE_STATE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowNameNotification, 0) == 0) {
    _updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowStateNotification, 0) == 0) {
    CFStringRef wstate = (CFStringRef)wGetNotificationInfoValue(userInfo, CFSTR("state"));
    if (CFStringCompare(wstate, CFSTR("omnipresent"), 0) == 0) {
      _updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE_DESKTOP);
    }
    else {
      _updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE_STATE);
    }
  }
  _validateWindowsItems(windows_menu, wwin);
}

static void _updateDesktopsMenu(WMenu *menu);

static void _desktopsObserver(CFNotificationCenterRef center,
                             void *menu,
                             CFNotificationName name,
                             const void *window,
                             CFDictionaryRef userInfo)
{
  _updateDesktopsMenu(menu);
}

static WMenu *_createWindowsMenu(WApplication *wapp)
{
  WMenu *windows_menu, *desktops_menu;
  WMenuItem *tmp_item;
  WScreen *scr = wapp->main_wwin->screen;
  
  desktops_menu = wMenuCreate(scr, _("Move Window To"), False);
  desktops_menu->app = wapp;
  _updateDesktopsMenu(desktops_menu);
  
  windows_menu = wMenuCreate(scr, _("Windows"), False);
  windows_menu->app = wapp;
  tmp_item = wMenuItemInsert(windows_menu, 0, _("Arrange in Front"), NULL, NULL);
  wMenuItemSetEnabled(windows_menu, tmp_item, False);
  tmp_item = wMenuAddItem(windows_menu, _("Miniaturize Window"), _miniaturizeWindow, NULL);
  wMenuItemSetShortcut(tmp_item, "Command+m");
  tmp_item = wMenuAddItem(windows_menu, _("Move Window To"), NULL, NULL);
  wMenuItemSetSubmenu(windows_menu, tmp_item, desktops_menu);
  
  tmp_item = wMenuAddItem(windows_menu, _("Shade Window"), _shadeWindow, NULL);
  /* tmp_item = wMenuAddItem(_menu, _("Resize/Move Window"), windowsCallback, NULL); */
  /* tmp_item = wMenuAddItem(_menu, _("Select Window"), windowsCallback, NULL); */
  tmp_item = wMenuAddItem(windows_menu, _("Zoom Window"), _zoomWindow, NULL);
  tmp_item = wMenuAddItem(windows_menu, _("Close Window"), _closeWindow, NULL);
  wMenuItemSetShortcut(tmp_item, "Command+w");

  /* TODO: think about "Options" submenu */

  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, _windowObserver,
                                  WMDidManageWindowNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, _windowObserver,
                                  WMDidUnmanageWindowNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, _windowObserver,
                                  WMDidChangeWindowStateNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, _windowObserver,
                                  WMDidChangeWindowFocusNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, _windowObserver,
                                  WMDidChangeWindowStackingNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, windows_menu, _windowObserver,
                                  WMDidChangeWindowNameNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);

  CFNotificationCenterAddObserver(scr->notificationCenter, desktops_menu, _desktopsObserver,
                                  WMDidChangeDesktopNameNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, desktops_menu, _desktopsObserver,
                                  WMDidCreateDesktopNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, desktops_menu, _desktopsObserver,
                                  WMDidDestroyDesktopNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);

  
  return windows_menu;
}

// "Windows > Move Window To" menu
//-------------------------------------------------------------------------------------------------

static void _switchDesktopCallback(WMenu *menu, WMenuItem *entry)
{
  WWindow *wwin = menu->frame->screen_ptr->focused_window;

  wSelectWindow(wwin, False);
  wWindowChangeDesktop(wwin, entry->index);
}

static void _updateDesktopsMenu(WMenu *desktops_menu)
{
  WScreen *scr = desktops_menu->frame->screen_ptr;
  char title[MAX_DESKTOPNAME_WIDTH + 1];
  WMenuItem *item;
  int i;

  // Remove deleted desktops
  for (i = desktops_menu->items_count; i >= scr->desktop_count; i--) {
    wMenuItemRemove(desktops_menu, i);
    desktops_menu->flags.realized = 0;
  }

  // Update names or add new desktops
  for (i = 0; i < scr->desktop_count; i++) {
    if (i < desktops_menu->items_count) {
      item = desktops_menu->items[i];
      if (strcmp(item->text, scr->desktops[i]->name) != 0) {
        wfree(item->text);
        strncpy(title, scr->desktops[i]->name, MAX_DESKTOPNAME_WIDTH);
        title[MAX_DESKTOPNAME_WIDTH] = 0;
        desktops_menu->items[i]->text = wstrdup(title);
        desktops_menu->flags.realized = 0;
      }
    } else {
      strncpy(title, scr->desktops[i]->name, MAX_DESKTOPNAME_WIDTH);
      title[MAX_DESKTOPNAME_WIDTH] = 0;
      item = wMenuAddItem(desktops_menu, title, _switchDesktopCallback, NULL);
    }

    /* workspace shortcut labels */
    item->rtext = NULL;
  }

  if (!desktops_menu->flags.realized) {
    wMenuRealize(desktops_menu);
  }
}

// "Tools" menu - Dock and Icon Yard
//-------------------------------------------------------------------------------------------------
static void _hideDock(WMenu *menu, WMenuItem *entry)
{
  WScreen *scr = menu->frame->screen_ptr;
  
  if (scr->dock->mapped) {
    wDockHideIcons(scr->dock);
    wfree(entry->text);
    entry->text = wstrdup("Show");
  } else {
    wDockShowIcons(scr->dock);
    wfree(entry->text);
    entry->text = wstrdup("Hide");
  }
}

static void _collapseDock(WMenu *menu, WMenuItem *entry)
{
  WScreen *scr = menu->frame->screen_ptr;
  
  if (scr->dock->collapsed == 0) {
    wDockCollapse(scr->dock);
    wfree(entry->text);
    entry->text = wstrdup("Uncollapse");
  } else {
    wDockUncollapse(scr->dock);
    wfree(entry->text);
    entry->text = wstrdup("Collapse");
  }
}

static void _hideIconYard(WMenu *menu, WMenuItem *entry)
{
  WScreen *scr = menu->frame->screen_ptr;
  
  if (scr->flags.icon_yard_mapped) {
    wIconYardHideIcons(scr);
    wfree(entry->text);
    entry->text = wstrdup("Show");
 }
  else {
    wIconYardShowIcons(scr);
    wfree(entry->text);
    entry->text = wstrdup("Hide");
  }
}

static WMenu *_createToolsMenu(WApplication *wapp)
{
  WScreen *scr = wapp->main_wwin->screen;
  WMenu *tools_menu, *dock_menu, *iconyard_menu;
  WMenuItem *tmp_item;
  
  tools_menu = wMenuCreate(scr, _("Tools"), False);
  tools_menu->app = wapp;
  
  dock_menu = wMenuCreate(scr, _("Dock"), False);
  dock_menu->app = wapp;
  //
  tmp_item = wMenuAddItem(dock_menu, _("Hide Dock"), _hideDock, NULL);
  wMenuItemSetShortcut(tmp_item, "Alternate+D");
  tmp_item = wMenuAddItem(dock_menu, _("Collapse Dock"), _collapseDock, NULL);
  //
  tmp_item = wMenuAddItem(tools_menu, _("Dock"), NULL, NULL);
  wMenuItemSetSubmenu(tools_menu, tmp_item, dock_menu);
  
  iconyard_menu = wMenuCreate(scr, _("Icon Yard"), False);
  iconyard_menu->app = wapp;
  tmp_item = wMenuAddItem(iconyard_menu, _("Hide Icon Yard"), _hideIconYard, NULL);
  wMenuItemSetShortcut(tmp_item, "Alternate+Y");
  tmp_item = wMenuAddItem(tools_menu, _("Icon Yard"), NULL, NULL);
  wMenuItemSetSubmenu(tools_menu, tmp_item, iconyard_menu);

  return tools_menu;
}

// General application menu code
//-------------------------------------------------------------------------------------------------
static WMenu *_submenuWithTitle(WMenu *menu, char *title)
{
  WMenu **submenus = menu->submenus;

  for (int i = 0; i < menu->submenus_count; i++) {
    if (!strcmp(submenus[i]->frame->title, title)) {
      return submenus[i];
    }
  }
  return NULL;
}

WMenu *wApplicationMenuCreate(WScreen *scr, WApplication *wapp)
{
  WMenu *menu, *info, *windows, *tools;
  WMenuItem *tmp_item;

  menu = wMenuCreate(scr, CFStringGetCStringPtr(wapp->appName, kCFStringEncodingUTF8), True);
  menu->app = wapp;

  // Info
  info = wMenuCreate(scr, _("Info"), False);
  tmp_item = wMenuAddItem(info, _("Info Panel..."), NULL, NULL);
  wMenuItemSetEnabled(info, tmp_item, False);
  tmp_item = wMenuAddItem(info, _("Preferences..."), NULL, NULL);
  wMenuItemSetEnabled(info, tmp_item, False);
  tmp_item = wMenuAddItem(menu, _("Info"), NULL, NULL);
  wMenuItemSetSubmenu(menu, tmp_item, info);

  // Windows
  windows = _createWindowsMenu(wapp);
  tmp_item = wMenuAddItem(menu, _("Windows"), NULL, NULL);
  wMenuItemSetSubmenu(menu, tmp_item, windows);

  // Tools
  tools = _createToolsMenu(wapp);
  tmp_item = wMenuAddItem(menu, _("Tools"), NULL, NULL);
  wMenuItemSetSubmenu(menu, tmp_item, tools);
  
  tmp_item = wMenuAddItem(menu, _("Hide"), mainCallback, wapp);
  /* tmp_item->rtext = wstrdup("h"); */
  wMenuItemSetShortcut(tmp_item, "Command+h");
  tmp_item = wMenuAddItem(menu, _("Hide Others"), mainCallback, wapp);
  /* tmp_item->rtext = wstrdup("H"); */
  wMenuItemSetShortcut(tmp_item, "Command+Shift+h");
  tmp_item = wMenuAddItem(menu, _("Quit"), mainCallback, wapp);
  wMenuItemSetShortcut(tmp_item, "Command+q");
  
  return menu;
}

void wApplicationMenuDestroy(WApplication *wapp)
{
  WMenu *windows_menu = _submenuWithTitle(wapp->app_menu, "Windows");
  
  CFNotificationCenterRemoveEveryObserver(wapp->main_wwin->screen->notificationCenter,
                                          windows_menu);
  wMenuUnmap(wapp->app_menu);
  wMenuDestroy(wapp->app_menu, True);
}

void wApplicationMenuOpen(WApplication *wapp, int x, int y)
{
  WScreen *scr = wapp->main_wwin->screen;
  WMenu *menu;
  int i;

  if (!wapp->app_menu) {
    WMLogError("Applicastion menu can't be opened because it was not created");
    return;
  }
  menu = wapp->app_menu;

  /* set client data */
  for (i = 0; i < menu->items_count; i++) {
    menu->items[i]->clientdata = wapp;
  }
  
  if (wapp->flags.hidden) {
    menu->items[3]->text = wstrdup(_("Unhide"));
  } else {
    menu->items[3]->text = wstrdup(_("Hide"));
  }

  menu->flags.realized = 0;
  wMenuRealize(menu);
  
  /* Place menu on screen */
  x -= menu->frame->core->width / 2;
  if (x + menu->frame->core->width > scr->width) {
    x = scr->width - menu->frame->core->width;
  }
  if (x < 0) {
    x = 0;
  }
  wMenuMapAt(menu, x, y, False);
}

void wApplicationMenuHide(WMenu *menu)
{
  WMenu *submenu;
  
  if (!menu) {
    return;
  }
  
  for (int i = 0; i < menu->submenus_count; i++) {
    submenu = menu->submenus[i];
    /* WMLogInfo("Hide submenu %s is mapped: %i brother mapped: %i", */
    /*           submenu->frame->title, submenu->flags.mapped, submenu->brother->flags.mapped); */
    wApplicationMenuHide(submenu);
    if (submenu->flags.brother) {
      wApplicationMenuHide(submenu->brother);
    }
  }

  if (menu->flags.mapped) {
    wMenuUnmap(menu);
    menu->flags.hidden = 1;
  }
}

void wApplicationMenuShow(WMenu *menu)
{
  WMenu *submenu;

  if (!menu) {
    return;
  }
  
  for (int i = 0; i < menu->submenus_count; i++) {
    submenu = menu->submenus[i];
    /* WMLogInfo("Show submenu %s is mapped: %i brother mapped: %i", */
    /*           submenu->frame->title, submenu->flags.mapped, submenu->brother->flags.mapped); */
    wApplicationMenuShow(submenu);
    if (submenu->flags.brother) {
      wApplicationMenuShow(submenu->brother);
    }
  }
  
  if (menu->flags.hidden && !menu->flags.mapped) {
    wMenuMap(menu);
    menu->flags.hidden = 0;
  }
}

WMenuItem *wMenuItemWithTitle(WMenu *menu, char *title)
{
  WMenuItem **items = menu->items;

  for (int i = 0; i < menu->items_count; i++) {
    if (!strcmp(items[i]->text, title)) {
      return items[i];
    }
  }
  return NULL;
}

// Menu state
//--------------------------------------------------------------------------------------------------

static CFStringRef _getMenuPath(WMenu *menu)
{
  WMenu *tmp_menu, *main_menu;
  CFStringRef menuPath;
  CFStringRef menuTitle;
  CFMutableArrayRef menuPathElements;

  // Get the top of the menu hierarchy
  main_menu = menu;
  while (main_menu->parent) {
    main_menu = main_menu->parent;
  }
  
  menuPathElements = CFArrayCreateMutable(kCFAllocatorDefault, 1, &kCFTypeArrayCallBacks);
  tmp_menu = menu;
  while (tmp_menu != main_menu) {
    menuTitle = CFStringCreateWithCString(kCFAllocatorDefault, tmp_menu->frame->title,
                                          kCFStringEncodingUTF8);
    CFArrayInsertValueAtIndex(menuPathElements, 0, menuTitle);
    CFRelease(menuTitle);
    tmp_menu = tmp_menu->parent;
  }
  if (CFArrayGetCount(menuPathElements) == 0) {
    CFArrayInsertValueAtIndex(menuPathElements, 0, CFSTR("/"));
  } else {
    CFArrayInsertValueAtIndex(menuPathElements, 0, CFSTR(""));
  }
  
  menuPath = CFStringCreateByCombiningStrings(kCFAllocatorDefault, menuPathElements, CFSTR("/"));
  CFRelease(menuPathElements);

  return menuPath;
}

static CFDictionaryRef _getMenuState(WMenu *menu)
{
  CFMutableDictionaryRef state;
  CFStringRef menuPath;
  CFNumberRef tmpNumber;
  
  state = CFDictionaryCreateMutable(kCFAllocatorDefault, 5,
                                    &kCFTypeDictionaryKeyCallBacks,
                                    &kCFTypeDictionaryValueCallBacks);

  menuPath = _getMenuPath(menu);
  CFDictionarySetValue(state, WMenuPath, menuPath);
  CFRelease(menuPath);
  
  // Type
  if (menu->flags.app_menu) {
    CFDictionarySetValue(state, WMenuType, WMenuTypeMain);
  } else if (menu->flags.tornoff) {
    CFDictionarySetValue(state, WMenuType, WMenuTypeTornOff);
  } else {
    CFDictionarySetValue(state, WMenuType, WMenuTypeAttached);
  }

  // Position
  tmpNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberShortType, &menu->frame_x);
  CFDictionarySetValue(state, WMenuPositionX, tmpNumber);
  CFRelease(tmpNumber);
  tmpNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberShortType, &menu->frame_y);
  CFDictionarySetValue(state, WMenuPositionY, tmpNumber);
  CFRelease(tmpNumber);

  return state;
}

void wApplicationMenuSaveState(WMenu *menu, CFMutableArrayRef menus_state)
{
  CFDictionaryRef info = NULL;
  CFStringRef menuType;
  WMenu *submenu = NULL;

  if (!menu) {
    WMLogError("wApplicationMenuSaveState was called with no `menu` specified!");
  }
  if (!menus_state) {
    WMLogError("wApplicationMenuSaveState was called with no `menus_state` specified!");
  }

  for (int i = 0; i < menu->submenus_count; i++) {
    submenu = menu->submenus[i];
    wApplicationMenuSaveState(submenu, menus_state);
    if (submenu->flags.brother && submenu->brother->flags.mapped) { // tornoff
      wApplicationMenuSaveState(submenu->brother, menus_state);
    }
  }

   if (!menu->flags.mapped) {
     return;
   }

  /* WMLogInfo("Saving state for `%s`", menu->frame->title); */
  info = _getMenuState(menu);
  menuType = CFDictionaryGetValue(info, WMenuType);
  if (CFStringCompare(menuType, WMenuTypeAttached, 0) != 0) {
    /* make parent map the original in place of the copy */
    if (menu->parent) {
      for (int i = 0; i < menu->parent->submenus_count; i++) {
        if (menu->parent->submenus[i] == menu->brother) {
          menu->parent->submenus[i] = menu;
        }
      }
    }
    CFArrayAppendValue(menus_state, info);
  }
  CFRelease(info);
}

static CFDictionaryRef _getMenuInfoFromState(WMenu *menu, CFArrayRef state)
{
  CFStringRef menuPath = _getMenuPath(menu);
  CFStringRef path;
  CFDictionaryRef info = NULL;

  if (!menu || !state) {
    return NULL;
  }

  for (int i = 0; i < CFArrayGetCount(state); i++) {
    info = CFArrayGetValueAtIndex(state, i);
    path = CFDictionaryGetValue(info, WMenuPath);
    if (CFStringCompare(path, menuPath, 0) == 0) {
      return info;
    }
  }
  
  return NULL;
}

static void _restoreMenuFromInfo(WMenu *menu, CFDictionaryRef menu_info)
{
  CFStringRef menuType;
  int x = 0, y = 0;

  if (!menu || !menu_info) {
    return;
  }
  CFNumberGetValue(CFDictionaryGetValue(menu_info, WMenuPositionX), kCFNumberShortType, &x);
  CFNumberGetValue(CFDictionaryGetValue(menu_info, WMenuPositionY), kCFNumberShortType, &y);
      
  /* WMLogInfo("Restoring submenu `%@` at %i, %i", CFDictionaryGetValue(menu_info, WMenuPath), x, y); */
      
  // map
  menuType = CFDictionaryGetValue(menu_info, WMenuType);
  if (CFStringCompare(menuType, WMenuTypeTornOff, 0) == 0) {
    menu->flags.tornoff = 1;
    wFrameWindowShowButton(menu->frame, WFF_RIGHT_BUTTON);
    /* make parent map the copy in place of the original */
    if (menu->parent) {
      for (int i = 0; i < menu->parent->submenus_count; i++) {
        if (menu->parent->submenus[i] == menu) {
          menu->parent->submenus[i] = menu->brother;
        }
      }
    }
  } else {
    menu->flags.tornoff = 0;
  }
  wMenuMapAt(menu, x, y, false);
}

void wApplicationMenuRestoreFromState(WMenu *menu, CFArrayRef state)
{
  CFDictionaryRef menu_info;
  WMenu *submenu;

  if (!menu || !state) {
    WMLogError("wApplicationMenuRestoreState was called without `menu` or `state` specified!");
    return;
  }

  for (int i = 0; i < menu->submenus_count; i++) {
    submenu = menu->submenus[i];
    wApplicationMenuRestoreFromState(submenu, state);
  }

  menu_info = _getMenuInfoFromState(menu, state);
  if (menu_info) {
    _restoreMenuFromInfo(menu, menu_info);
  }
}

// Menu state
//--------------------------------------------------------------------------------------------------
static WMenuItem *_itemForShortcut(WMenu *menu, KeyCode keycode, unsigned int modifiers)
{
  WMenuItem *item;

  /* WMLogInfo("Searching for shortcut in %s", menu->frame->title); */

  // Go through menu items
  for (int i = 0; i < menu->items_count; i++) {
    item = menu->items[i];
    if (item->submenu_index >= 0) {
      item = _itemForShortcut(menu->submenus[item->submenu_index], keycode, modifiers);
      if (item != NULL) {
        return item;
      }
    } else if (item->shortcut && item->shortcut->keycode == keycode &&
               item->shortcut->modifier == modifiers) {
      /* WMLogInfo("Found menu item `%s` keycode: %i modifiers: %i", */
      /*           item->text, item->shortcut->keycode, item->shortcut->modifier); */
      return item;
    }
  }
  
  return NULL;
}

Bool wApplicationMenuHandleKeyPress(WWindow *focused_window, XEvent *event)
{
  WApplication *wapp = wApplicationForWindow(focused_window);
  WMenuItem *item;
  WMenuItem *parent_item = NULL;
  unsigned int modifiers;

  /* WMLogInfo("App menu key press. Modifier: %x Key: %x", modifiers, keycode); */

  /* Key presses without modifiers or modifiers-only is not menu shortcut */
  if (!event->xkey.keycode || !event->xkey.state) {
    return False;
  }

  /* ignore CapsLock */
  modifiers = event->xkey.state & w_global.shortcut.modifiers_mask;

  if (wapp && wapp->app_menu) {
    item = _itemForShortcut(wapp->app_menu, event->xkey.keycode, modifiers);
    if (item != NULL) {
      /* WMLogInfo("Menu item %s found!", item->text); */
      if (!item->menu->flags.mapped) {
        WMenu *menu = item->menu;
        while (!menu->flags.mapped && menu->parent) {
          /* WMLogInfo("Checking menu %s", menu->frame->title); */
          parent_item = wMenuItemWithTitle(menu->parent, menu->frame->title);
          menu = parent_item->menu;
        }
        if (parent_item) {
          /* WMLogInfo("Parent menu %s item index %i", parent_item->menu->frame->title, parent_item->index); */
          wMenuItemPaint(parent_item->menu, parent_item->index, True);
        }
      } else {
        wMenuItemPaint(item->menu, item->index, True);
      }
      XFlush(dpy);
      XSync(dpy, False);
      usleep(100000);

      if (item->clientdata == NULL) {
        item->clientdata = event;
      }
      (*item->callback) (item->menu, item);
      
      if (!item->menu->flags.mapped) {
        if (parent_item) {
          wMenuItemPaint(parent_item->menu, parent_item->index, False);
        }
      } else {
        wMenuItemPaint(item->menu, item->index, False);
      }
      return True;
    }
  }

  return False;
}
