#include <string.h>
#include <stdio.h>

#include <core/log_utils.h>
#include <core/string_utils.h>

#include "appmenu.h"
#include "window.h"
#include "framewin.h"
#include "actions.h"
#include "misc.h"
#include "workspace.h"

static CFStringRef WMenuPath = CFSTR("Path");
static CFStringRef WMenuType = CFSTR("Type");
static CFStringRef WMenuSelectedItem = CFSTR("SelectedItem");
static CFStringRef WMenuPositionX = CFSTR("X");
static CFStringRef WMenuPositionY = CFSTR("Y");
static CFStringRef WMenuTypeMain = CFSTR("Main");
static CFStringRef WMenuTypeTornOff = CFSTR("TornOff");
static CFStringRef WMenuTypeAttached = CFSTR("Attached");

// Main application menu
//-------------------------------------------------------------------------------------------------
static void nullCallback(WMenu *menu, WMenuItem *entry)
{
  WMLogInfo("Item %s was clicked in menu %s", entry->text, menu->frame->title);
}

static void mainCallback(WMenu *menu, WMenuItem *entry)
{
  WApplication *wapp = (WApplication *)entry->clientdata;
  
  if (!strcmp(entry->text, "Hide")) {
    wHideApplication(wapp);
  } else if (!strcmp(entry->text, "Hide Others")) {
    wHideOtherApplications(wapp->last_focused);
  }
}

// "Windows" menu
//-------------------------------------------------------------------------------------------------
#define MAX_WINDOWLIST_WIDTH    400
#define ACTION_ADD              0
#define ACTION_REMOVE           1
#define ACTION_CHANGE           2
#define ACTION_CHANGE_WORKSPACE 3
#define ACTION_CHANGE_STATE     4

static void focusWindow(WMenu *menu, WMenuItem *entry)
{
  WWindow *wwin = (WWindow *)entry->clientdata;
  wWindowSingleFocus(wwin);
}

static void windowsCallback(WMenu *menu, WMenuItem *entry) {}

static int menuIndexForWindow(WMenu *menu, WWindow *wwin, int old_pos)
{
  int idx;

  if (menu->items_count <= old_pos)
    return -1;

#define WS(i)  ((WWindow*)menu->items[i]->clientdata)->frame->workspace
  if (old_pos >= 0) {
    if (WS(old_pos) >= wwin->frame->workspace
        && (old_pos == 0 || WS(old_pos - 1) <= wwin->frame->workspace)) {
      return old_pos;
    }
  }
#undef WS

  for (idx = 0; idx < menu->items_count; idx++) {
    WWindow *tw = (WWindow *)menu->items[idx]->clientdata;

    if (!tw || (!IS_OMNIPRESENT(tw) && tw->frame->workspace > wwin->frame->workspace)) {
      break;
    }
  }

  return idx;
}

static void updateWindowsMenu(WMenu *windows_menu, WWindow *wwin, int action)
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
      idx = menuIndexForWindow(windows_menu, wwin, -1);
    }

    entry = wMenuInsertItem(windows_menu, idx+1, t, focusWindow, wwin);
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
          wMenuRemoveItem(windows_menu, i);
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

static void switchDesktopCallback(WMenu *menu, WMenuItem *entry)
{
  WWindow *wwin = menu->frame->screen_ptr->focused_window;

  wSelectWindow(wwin, False);
  wWindowChangeWorkspace(wwin, entry->order);
}

static void updateDesktopsMenu(WMenu *menu)
{
  WScreen *scr = menu->frame->screen_ptr;
  char title[MAX_WORKSPACENAME_WIDTH + 1];
  WMenuItem *entry;
  int i;

  for (i = 0; i < scr->workspace_count; i++) {
    if (i < menu->items_count) {

      entry = menu->items[i];
      if (strcmp(entry->text, scr->workspaces[i]->name) != 0) {
        wfree(entry->text);
        strncpy(title, scr->workspaces[i]->name, MAX_WORKSPACENAME_WIDTH);
        title[MAX_WORKSPACENAME_WIDTH] = 0;
        menu->items[i]->text = wstrdup(title);
        menu->items[i]->rtext = GetShortcutKey(wKeyBindings[WKBD_MOVE_WORKSPACE1 + i]);
        menu->flags.realized = 0;
      }
    } else {
      strncpy(title, scr->workspaces[i]->name, MAX_WORKSPACENAME_WIDTH);
      title[MAX_WORKSPACENAME_WIDTH] = 0;

      entry = wMenuAddItem(menu, title, switchDesktopCallback, NULL);
      entry->rtext = GetShortcutKey(wKeyBindings[WKBD_MOVE_WORKSPACE1 + i]);

      menu->flags.realized = 0;
    }

    /* workspace shortcut labels */
    if (i / 10 == scr->current_workspace / 10)
      entry->rtext = GetShortcutKey(wKeyBindings[WKBD_MOVE_WORKSPACE1 + (i % 10)]);
    else
      entry->rtext = NULL;
  }

  if (!menu->flags.realized) {
    wMenuRealize(menu);
  }
}

static void windowObserver(CFNotificationCenterRef center,
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
    updateWindowsMenu(windows_menu, wwin, ACTION_ADD);
  }
  else if (CFStringCompare(name, WMDidUnmanageWindowNotification, 0) == 0) {
    updateWindowsMenu(windows_menu, wwin, ACTION_REMOVE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowFocusNotification, 0) == 0) {
    updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE_STATE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowNameNotification, 0) == 0) {
    updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE);
  }
  else if (CFStringCompare(name, WMDidChangeWindowStateNotification, 0) == 0) {
    CFStringRef wstate = (CFStringRef)wGetNotificationInfoValue(userInfo, CFSTR("state"));
    if (CFStringCompare(wstate, CFSTR("omnipresent"), 0) == 0) {
      updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE_WORKSPACE);
    }
    else {
      updateWindowsMenu(windows_menu, wwin, ACTION_CHANGE_STATE);
    }
  }
}

static WMenu *createWindowsMenu(WApplication *wapp)
{
  WMenu *_menu, *desktops_menu;
  WMenuItem *tmp_item;
  WScreen *scr = wapp->main_wwin->screen;
  
  desktops_menu = wMenuCreate(scr, _("Move Window To"), False);
  desktops_menu->app = wapp;
  updateDesktopsMenu(desktops_menu);
  
  _menu = wMenuCreate(scr, _("Windows"), False);
  _menu->app = wapp;
  wMenuInsertItem(_menu, 0, _("Arrange in Front"), windowsCallback, NULL);
  tmp_item = wMenuAddItem(_menu, _("Miniaturize Window"), windowsCallback, NULL);
  tmp_item->rtext = wstrdup("m");
  tmp_item = wMenuAddItem(_menu, _("Move Window To"), windowsCallback, NULL);
  wMenuItemSetSubmenu(_menu, tmp_item, desktops_menu);
  
  tmp_item = wMenuAddItem(_menu, _("Shade Window"), windowsCallback, NULL);
  tmp_item = wMenuAddItem(_menu, _("Resize/Move Window"), windowsCallback, NULL);
  tmp_item = wMenuAddItem(_menu, _("Select Window"), windowsCallback, NULL);
  tmp_item = wMenuAddItem(_menu, _("Zoom window"), windowsCallback, NULL);
  tmp_item = wMenuAddItem(_menu, _("Close Window"), windowsCallback, NULL);
  tmp_item->rtext = wstrdup("w");

  CFNotificationCenterAddObserver(scr->notificationCenter, _menu, windowObserver,
                                  WMDidManageWindowNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, _menu, windowObserver,
                                  WMDidUnmanageWindowNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, _menu, windowObserver,
                                  WMDidChangeWindowStateNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, _menu, windowObserver,
                                  WMDidChangeWindowFocusNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, _menu, windowObserver,
                                  WMDidChangeWindowStackingNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(scr->notificationCenter, _menu, windowObserver,
                                  WMDidChangeWindowNameNotification, NULL,
                                  CFNotificationSuspensionBehaviorDeliverImmediately);

  return _menu;
}

static WMenu *submenuWithTitle(WMenu *menu, char *title)
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
  WMenu *menu, *info, *windows;
  WMenuItem *info_item, *windows_item, *tmp_item;

  menu = wMenuCreate(scr, CFStringGetCStringPtr(wapp->appName, kCFStringEncodingUTF8), True);
  menu->app = wapp;
  
  info = wMenuCreate(scr, _("Info"), False);
  wMenuAddItem(info, _("Info Panel..."), nullCallback, NULL);
  tmp_item = wMenuAddItem(info, _("Preferences..."), nullCallback, NULL);
  info_item = wMenuAddItem(menu, _("Info"), NULL, NULL);
  wMenuItemSetSubmenu(menu, info_item, info);

  windows = createWindowsMenu(wapp);
  windows_item = wMenuAddItem(menu, _("Windows"), NULL, NULL);
  wMenuItemSetSubmenu(menu, windows_item, windows);
  
  tmp_item = wMenuAddItem(menu, _("Hide"), mainCallback, wapp);
  tmp_item->rtext = wstrdup("h");
  tmp_item = wMenuAddItem(menu, _("Hide Others"), mainCallback, wapp);
  tmp_item->rtext = wstrdup("H");
  tmp_item = wMenuAddItem(menu, _("Quit"), mainCallback, wapp);
  tmp_item->rtext = wstrdup("q");
  
  return menu;
}

void wApplicationMenuDestroy(WApplication *wapp)
{
  WMenu *windows_menu = submenuWithTitle(wapp->app_menu, "Windows");
  
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

void wApplicationMenuClose(WApplication *wapp)
{
  WMenu *main_menu;
  WMenu *tmp_menu;

  main_menu = wapp->app_menu;
  if (!main_menu) {
    return;
  }
  
  for (int i = 0; i < main_menu->submenus_count; i++) {
    tmp_menu = main_menu->submenus[i];
    /* WMLogInfo("Unmap submenu %s is mapped: %i brother mapped: %i", */
    /*           tmp_menu->frame->title, tmp_menu->flags.mapped, tmp_menu->brother->flags.mapped); */
    if (tmp_menu->flags.mapped) {
      wMenuUnmap(tmp_menu);
    } else if (tmp_menu->flags.brother && tmp_menu->brother->flags.mapped) {
      wMenuUnmap(tmp_menu->brother);
    }
  }
  wMenuUnmap(wapp->app_menu);
}

// Menu state
//--------------------------------------------------------------------------------------------------

static CFStringRef getMenuPath(WMenu *menu)
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

/* Live state is used on application activation and deactivation. */
static CFDictionaryRef getMenuState(WMenu *menu, Boolean is_live)
{
  CFMutableDictionaryRef state;
  CFStringRef menuPath;
  CFNumberRef tmpNumber;
  short default_index = -1;
  
  state = CFDictionaryCreateMutable(kCFAllocatorDefault, 5,
                                    &kCFTypeDictionaryKeyCallBacks,
                                    &kCFTypeDictionaryValueCallBacks);

  menuPath = getMenuPath(menu);
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
  tmpNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberShortType,
                             is_live ? &menu->selected_item_index : &default_index);
  CFDictionarySetValue(state, WMenuSelectedItem, tmpNumber);
  CFRelease(tmpNumber);

  return state;
}

void wApplicationMenuSaveState(WMenu *menu, CFMutableArrayRef menus_state, Boolean is_live)
{
  CFDictionaryRef info = NULL;
  CFStringRef menuType;
  WMenu *submenu = NULL;

  for (int i = 0; i < menu->submenus_count; i++) {
    submenu = menu->submenus[i];
    if (submenu->flags.mapped) {
      wApplicationMenuSaveState(submenu, menus_state, is_live);
    } else if (submenu->flags.brother && submenu->brother->flags.mapped) {// tornoff
      wApplicationMenuSaveState(submenu->brother, menus_state, is_live);
    }
  }

  /* WMLogInfo("Saving state for `%s`", menu->frame->title); */
  info = getMenuState(menu, is_live);
  menuType = CFDictionaryGetValue(info, WMenuType);
  if (is_live == true || CFStringCompare(menuType, WMenuTypeAttached, 0) != 0) {
    CFArrayAppendValue(menus_state, info);
  }
  CFRelease(info);
}

static CFDictionaryRef menuInfoFromState(WMenu *menu, CFArrayRef state)
{
  CFStringRef menuPath = getMenuPath(menu);
  CFStringRef path;
  CFDictionaryRef info = NULL;

  for (int i = 0; i < CFArrayGetCount(state); i++) {
    info = CFArrayGetValueAtIndex(state, i);
    path = CFDictionaryGetValue(info, WMenuPath);
    if (CFStringCompare(path, menuPath, 0) == 0) {
      return info;
    }
  }
  
  return NULL;
}

static void restoreMenuFromInfo(WMenu *menu, CFDictionaryRef menu_info)
{
  CFStringRef menuType;
  int x = 0, y = 0, selected_index = -1;

  if (!menu_info) {
    return;
  }
  CFNumberGetValue(CFDictionaryGetValue(menu_info, WMenuPositionX), kCFNumberShortType, &x);
  CFNumberGetValue(CFDictionaryGetValue(menu_info, WMenuPositionY), kCFNumberShortType, &y);
  CFNumberGetValue(CFDictionaryGetValue(menu_info, WMenuSelectedItem), kCFNumberShortType,
                   &selected_index);
      
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
  menu->selected_item_index = selected_index;
  wMenuMapAt(menu, x, y, false);
}

void wApplicationMenuRestoreFromState(WApplication *wapp, CFArrayRef state)
{
  CFDictionaryRef menu_info;
  WMenu *main_menu = wapp->app_menu;
  WMenu *submenu;

  // Restore main menu
  menu_info = menuInfoFromState(main_menu, state);
  restoreMenuFromInfo(main_menu, menu_info);

  // Submenus
  for (int i = 0; i < main_menu->submenus_count; i++) {
    submenu = main_menu->submenus[i];
    menu_info = menuInfoFromState(submenu, state);
    if (menu_info) {
      restoreMenuFromInfo(submenu, menu_info);
    }
  }
}
