/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1998-2003 Dan Pascu
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

#include <X11/Xlib.h>
#include <string.h>

#include <CoreFoundation/CFString.h>

#include <core/util.h>
#include <core/log_utils.h>
#include <core/string_utils.h>
#include <core/wevent.h>
#include <core/wuserdefaults.h>

#include "GNUstep.h"
#include "WM.h"
#include "menu.h"
#include "window.h"
#include "window_attributes.h"
#include "appicon.h"
#include "application.h"
#include "properties.h"
#include "desktop.h"
#include "dock.h"
#include "defaults.h"
#include "startup.h"
#include "actions.h"
#include "iconyard.h"
#include "client.h"
#include "framewin.h"
#include "appmenu.h"

#include <Workspace+WM.h>

/******** Notification observers ********/

static void postWorkspaceNotification(WWindow *wwin, CFStringRef name)
{
  CFMutableDictionaryRef info;
  CFNumberRef windowID;
  CFStringRef appName;

  if (wwin->screen->notificationCenter) {
    info = CFDictionaryCreateMutable(kCFAllocatorDefault, 2, &kCFTypeDictionaryKeyCallBacks,
                                     &kCFTypeDictionaryValueCallBacks);
    windowID = CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &wwin->client_win);
    CFDictionaryAddValue(info, CFSTR("WindowID"), windowID);
    appName =
        CFStringCreateWithCString(kCFAllocatorDefault, wwin->wm_class, CFStringGetSystemEncoding());
    CFDictionaryAddValue(info, CFSTR("ApplicationName"), appName);

    CFNotificationCenterPostNotification(wwin->screen->notificationCenter, name,
                                         CFSTR("GSWorkspaceNotification"), info, TRUE);
    CFRelease(windowID);
    CFRelease(appName);
    CFRelease(info);
  }
}

static void shadeObserver(CFNotificationCenterRef center,
                          void *wobserver,  // wapp
                          CFNotificationName name,
                          const void *object,  // object - ignored
                          CFDictionaryRef userInfo)
{
  CFNumberRef windowID = CFDictionaryGetValue(userInfo, CFSTR("WindowID"));
  /* CFStringRef appName = CFDictionaryGetValue(userInfo, CFSTR("ApplicationName")); */
  /* const char *app_name = CFStringGetCStringPtr(appName, CFStringGetSystemEncoding()); */
  WApplication *observer_wapp = (WApplication *)wobserver;
  WApplication *wapp;
  Window window = 0;
  WWindow *wwin;

  if (windowID) {
    WMLogInfo("Will shade window %lu", window);
    CFNumberGetValue(windowID, kCFNumberLongType, &window);
    wwin = wWindowFor(window);
    wapp = wApplicationOf(wwin->main_window);

    /* if (!wapp || wapp->main_window_desc != observer_wapp->main_window_desc) { */
    if (wapp != observer_wapp) {
      WMLogInfo("WM wapp %s received foreing notification", observer_wapp->main_wwin->wm_instance);
      return;
    }

    WMLogInfo("WM will shade window %lu for application %s.", window, wwin->wm_instance);
    if (wwin->flags.shaded == 1) {
      wUnshadeWindow(wwin);
    } else {
      wShadeWindow(wwin);
    }
    postWorkspaceNotification(wwin, WMDidShadeWindowNotification);
  }
}

static void hideObserver(CFNotificationCenterRef center,
                         void *wobserver,  // wapp
                         CFNotificationName name,
                         const void *object,  // object - ignored
                         CFDictionaryRef userInfo)
{
  WApplication *wapp = (WApplication *)wobserver;
  CFStringRef appName = CFDictionaryGetValue(userInfo, CFSTR("NSApplicationName"));

  if (!appName || CFStringCompare(appName, wapp->appName, 0) != 0) {
    // Unknown application or application is not observed object
    // WMLogInfo("hideObserver: `%@` application is not observed object - %@.",
    //           appName, wapp->appName);
    return;
  }

  wapp->flags.hidden = 1;
  WMLogInfo("hideObserver: %@ did HIDE.", wapp->appName);
}

static void unhideObserver(CFNotificationCenterRef center,
                         void *wobserver,  // wapp
                         CFNotificationName name,
                         const void *object,  // object - ignored
                         CFDictionaryRef userInfo)
{
  WApplication *wapp = (WApplication *)wobserver;
  CFStringRef appName = CFDictionaryGetValue(userInfo, CFSTR("NSApplicationName"));

  if (!appName || CFStringCompare(appName, wapp->appName, 0) != 0) {
    // Unknown application or application is not observed object
    // WMLogInfo("unhideObserver: `%@` application is not observed object - %@.",
    //           appName, wapp->appName);
    return;
  }
  wapp->flags.hidden = 0;
  WMLogInfo("unhideObserver: %@ did UNHIDE.", wapp->appName);
}

static void hideOthersObserver(CFNotificationCenterRef center,
                               void *wobserver,  // wapp
                               CFNotificationName name,
                               const void *object,  // object - ignored
                               CFDictionaryRef userInfo)
{
  CFStringRef appName = CFDictionaryGetValue(userInfo, CFSTR("ApplicationName"));
  WApplication *wapp = (WApplication *)wobserver;

  if (wApplicationOf(wapp->main_window) == NULL) {
    // WMLogCritical("You've forgot to remove CFNotificationObserver to WMShouldHideOthersNotification!!!");
    return;
  }

  if (CFStringCompare(appName, wapp->appName, 0) == 0) {
    wApplicationHideOthers(wapp->main_wwin);
  }
}

static WWindow *makeMainWindow(WScreen *scr, Window window)
{
  WWindow *wwin;
  XWindowAttributes attr;

  if (!XGetWindowAttributes(dpy, window, &attr))
    return NULL;

  wwin = wWindowCreate();
  wwin->screen = scr;
  wwin->client_win = window;
  wwin->main_window = window;
  wwin->wm_hints = XGetWMHints(dpy, window);

  PropGetWMClass(window, &wwin->wm_class, &wwin->wm_instance);
  if (wwin->wm_class != NULL && strcmp(wwin->wm_class, "GNUstep") == 0)
    wwin->flags.is_gnustep = 1;

  wDefaultFillAttributes(wwin->wm_instance, wwin->wm_class, &wwin->user_flags,
                         &wwin->defined_user_flags, True);

  XSelectInput(dpy, window, attr.your_event_mask | PropertyChangeMask | StructureNotifyMask);
  return wwin;
}

WApplication *wApplicationOf(Window window)
{
  WApplication *wapp;

  if (window == None)
    return NULL;
  if (XFindContext(dpy, window, w_global.context.app_win, (XPointer *)&wapp) != XCSUCCESS)
    return NULL;
  return wapp;
}

WApplication *wApplicationForWindow(struct WWindow *wwin)
{
  return wApplicationOf(wwin->main_window);
}

static BOOL _isWindowAlreadyRegistered(WApplication *wapp, WWindow *wwin)
{
  CFMutableArrayRef windows = wapp->windows;
  WWindow *w;

  /* for (unsigned i = 0; i < WMGetArrayItemCount(windows); i++) { */
  for (unsigned i = 0; i < CFArrayGetCount(windows); i++) {
    w = (WWindow *)CFArrayGetValueAtIndex(windows, i);
    if (w == wwin)
      return True;
  }

  return False;
}

void wApplicationAddWindow(WApplication *wapp, WWindow *wwin)
{
  int window_level = WINDOW_LEVEL(wwin);

  if (!wapp)
    return;

  WMLogInfo("ADD window: %lu level:%i name: %s refcount=%i", wwin->client_win, window_level,
            wwin->wm_instance, wapp->refcount);

  if (wapp->app_icon && wapp->app_icon->flags.docked && wapp->app_icon->flags.relaunching &&
      wapp->main_wwin->fake_group) {
    wDockFinishLaunch(wapp->app_icon);
  }

  if (_isWindowAlreadyRegistered(wapp, wwin))
    return;

  if (window_level == NSMainMenuWindowLevel)
    wapp->gsmenu_wwin = wwin;

  /* Do not add short-living objects to window list: tooltips, submenus, popups, etc. */
  if (window_level != NSNormalWindowLevel && window_level != NSFloatingWindowLevel)
    return;

  CFArrayAppendValue(wapp->windows, wwin);
  wapp->refcount++;
}

void wApplicationRemoveWindow(WApplication *wapp, WWindow *wwin)
{
  int window_count;
  WWindow *awin;

  /* Application could be already destroyed */
  if (wapp == NULL || wapp->windows == NULL || wwin == NULL)
    return;

  window_count = CFArrayGetCount(wapp->windows);

  WMLogInfo("REMOVE window: %lu name: %s WApplication refcount=%i", wwin->client_win,
            wwin->wm_instance, wapp->refcount);

  for (int i = 0; i < window_count; i++) {
    awin = (WWindow *)CFArrayGetValueAtIndex(wapp->windows, i);
    if (awin == wwin) {
      if (wwin == wapp->last_focused)
        wapp->last_focused = NULL;
      CFArrayRemoveValueAtIndex(wapp->windows, i);
      wapp->refcount--;
      break;
    }
  }
}

WApplication *wApplicationCreate(WWindow *wwin)
{
  WScreen *scr = wwin->screen;
  Window main_window = wwin->main_window;
  WApplication *wapp;
  WWindow *leader;

  if (main_window == None || main_window == scr->root_win)
    return NULL;

  {
    Window root;
    int foo;
    unsigned int bar;
    /* check if the window is valid */
    if (!XGetGeometry(dpy, main_window, &root, &foo, &foo, &bar, &bar, &bar, &bar))
      return NULL;
  }

  wapp = wApplicationOf(main_window);
  if (wapp) {
    wApplicationAddWindow(wapp, wwin);
    return wapp;
  }

  WMLogInfo("CREATE for window: %lu level:%i name: %s", wwin->client_win, WINDOW_LEVEL(wwin),
            wwin->wm_instance);

  wapp = wmalloc(sizeof(WApplication));

  wapp->windows = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);

  wapp->refcount = 1;
  wapp->last_focused = wwin;
  wapp->urgent_bounce_timer = NULL;
  wapp->gsmenu_wwin = NULL;
  wapp->flags.is_gnustep = wwin->flags.is_gnustep;
  if (wwin->flags.is_gnustep) {
    wapp->appName =
        CFStringCreateWithCString(kCFAllocatorDefault, wwin->wm_instance, kCFStringEncodingUTF8);
  } else {
    wapp->appName =
        CFStringCreateWithCString(kCFAllocatorDefault, wwin->wm_class, kCFStringEncodingUTF8);
  }

  wApplicationAddWindow(wapp, wwin);

  wapp->last_desktop = wwin->screen->current_desktop;

  wapp->main_window = main_window;
  wapp->main_wwin = makeMainWindow(scr, main_window);
  if (!wapp->main_wwin) {
    wfree(wapp);
    return NULL;
  }

  wapp->main_wwin->fake_group = wwin->fake_group;
  wapp->main_wwin->net_icon_image = RRetainImage(wwin->net_icon_image);

  leader = wWindowFor(main_window);
  if (leader)
    leader->main_window = main_window;

  /* Set application wide attributes from the leader */
  wapp->flags.hidden = WFLAGP(wapp->main_wwin, start_hidden);
  wapp->flags.emulated = WFLAGP(wapp->main_wwin, emulate_appicon);

  /* application descriptor */
  XSaveContext(dpy, main_window, w_global.context.app_win, (XPointer)wapp);

  create_appicon_for_application(wapp, wwin);

  /* Application menu */
  if (!wapp->flags.is_gnustep) {
    wapp->app_menu = wApplicationMenuCreate(scr, wapp);
    wapp->appState = (CFMutableDictionaryRef)WMUserDefaultsRead(wapp->appName, false);
    if (wapp->appState) {
      CFRetain(wapp->appState);
      wapp->menus_state =
          (CFMutableArrayRef)CFDictionaryGetValue(wapp->appState, CFSTR("MenusState"));
    }
  }

  if (!scr->wapp_list) {
    scr->wapp_list = wapp;
    wapp->prev = NULL;
    wapp->next = NULL;
  } else {
    WApplication *wa = scr->wapp_list;
    while (wa->next)
      wa = wa->next;
    wa->next = wapp;
    wapp->prev = wa;
    wapp->next = NULL;
    wApplicationMakeFirst(wapp);
  }

  WMLogInfo("WApplication `%s` was created! Prev `%s` Next `%s`", wwin->wm_instance,
            wapp->prev ? wapp->prev->main_wwin->wm_instance : "NULL",
            wapp->next ? wapp->next->main_wwin->wm_instance : "NULL");

  if (scr->notificationCenter) {
    CFNotificationCenterAddObserver(scr->notificationCenter, wapp, shadeObserver,
                                    WMShouldShadeWindowNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(scr->notificationCenter, wapp, hideOthersObserver,
                                    WMShouldHideOthersNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    // CFNotificationCenterAddObserver(scr->notificationCenter, wapp, hideObserver,
    //                                 CFSTR("NSApplicationDidHideNotification"), NULL,
    //                                 CFNotificationSuspensionBehaviorDeliverImmediately);
    // CFNotificationCenterAddObserver(scr->notificationCenter, wapp, unhideObserver,
    //                                 CFSTR("NSApplicationDidUnhideNotification"), NULL,
    //                                 CFNotificationSuspensionBehaviorDeliverImmediately);

    // Notify Workspace's ProcessManager
    CFNotificationCenterPostNotification(scr->notificationCenter,
                                         WMDidCreateApplicationNotification, wapp, NULL, true);
  }

  return wapp;
}

WApplication *wApplicationWithName(WScreen *scr, char *app_name)
{
  WApplication *app = scr ? scr->wapp_list : wDefaultScreen()->wapp_list;

  while (app) {
    if (!strcmp(app->main_wwin->wm_instance, app_name))
      return app;
    app = app->next;
  }

  return NULL;
}

void wApplicationDestroy(WApplication *wapp)
{
  WWindow *wwin;
  WScreen *scr;

  if (!wapp)
    return;

  WMLogInfo("DESTROY main window:%lu name:%s windows #:%li refcount:%i", wapp->main_window,
            wapp->app_icon->wm_instance, CFArrayGetCount(wapp->windows), wapp->refcount);

  wapp->refcount--;
  if (wapp->refcount > 0)
    return;

  scr = wapp->main_wwin->screen;
  
  CFNotificationCenterRemoveEveryObserver(scr->notificationCenter, wapp);

  CFArrayRemoveAllValues(wapp->windows);
  CFRelease(wapp->windows);
  /* WMLogError("wapp->windows retain count: %li", CFGetRetainCount(wapp->windows)); */

  if (wapp->app_menu && wapp->app_menu->flags.mapped) {
    /* saves app menu state */
    if (wapp->menus_state == NULL) {
      wapp->menus_state = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    } else {
      CFArrayRemoveAllValues(wapp->menus_state);
    }
    wApplicationMenuSaveState(wapp->app_menu, wapp->menus_state);
    wApplicationMenuHide(wapp->app_menu);
    wApplicationMenuDestroy(wapp);
    /* save app state */
    CFDictionaryAddValue(wapp->appState, CFSTR("MenusState"), wapp->menus_state);
    WMUserDefaultsWrite(wapp->appState, wapp->appName);
    CFRelease(wapp->menus_state);
  }
  if (!wapp->flags.is_gnustep) {
    CFRelease(wapp->appState);
  }
  CFRelease(wapp->appName);

  if (wapp->urgent_bounce_timer) {
    WMDeleteTimerHandler(wapp->urgent_bounce_timer);
    wapp->urgent_bounce_timer = NULL;
  }
  if (wapp->flags.bouncing) {
    /* event.c:handleDestroyNotify forced this destroy
       and thereby overlooked the bounce callback */
    wapp->refcount = 1;
    return;
  }

  // Notify Workspace's ProcessManager
  if (!wapp->flags.is_gnustep) {
    CFNotificationCenterPostNotification(scr->notificationCenter,
                                         WMDidDestroyApplicationNotification, wapp, NULL, TRUE);
  }

  if (wapp == scr->wapp_list) {
    if (wapp->next)
      wapp->next->prev = NULL;
    scr->wapp_list = wapp->next;
  } else {
    if (wapp->next)
      wapp->next->prev = wapp->prev;
    if (wapp->prev)
      wapp->prev->next = wapp->next;
  }

  XDeleteContext(dpy, wapp->main_window, w_global.context.app_win);

  /* Remove application icon */
  removeAppIconFor(wapp);

  wwin = wWindowFor(wapp->main_wwin->client_win);

  wWindowDestroy(wapp->main_wwin);
  if (wwin) {
    /* undelete client window context that was deleted in wWindowDestroy */
    XSaveContext(dpy, wwin->client_win, w_global.context.client_win,
                 (XPointer)&wwin->client_descriptor);
  }

  wfree(wapp);
  wapp = NULL;
  WMLogInfo("DESTROY END.");
}

void wApplicationActivate(WApplication *wapp)
{
  WScreen *scr = wapp->main_wwin->screen;

  WMLogInfo("wApplicationActivate %s current WS:%i last WS:%i app WS:%i",
            wapp->main_wwin->wm_instance, scr->current_desktop, scr->last_desktop,
            wapp->last_desktop);

  if (wapp->last_desktop != scr->current_desktop && scr->last_desktop == scr->current_desktop) {
    wDesktopChange(scr, wapp->last_desktop,
                   wapp->flags.is_gnustep ? wapp->gsmenu_wwin : wapp->last_focused);
  }

  wApplicationMakeFirst(wapp);

  if (wapp->flags.is_gnustep || wapp->app_menu->flags.mapped) {
    return;
  }

  if (wapp->menus_state && !wapp->app_menu->flags.restored) {
    wApplicationMenuRestoreFromState(wapp->app_menu, wapp->menus_state);
    wapp->app_menu->flags.restored = 1;
  } else if (wapp->app_menu->flags.hidden) {
    wApplicationMenuShow(wapp->app_menu);
  } else {
    wMenuMap(wapp->app_menu);
  }

  if (!wapp->appState) {
    wapp->appState = CFDictionaryCreateMutable(
        kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  }

  if (scr->notificationCenter) {
    CFNotificationCenterPostNotification(scr->notificationCenter,
                                         WMDidActivateApplicationNotification, wapp, NULL, TRUE);
  }
}

void wApplicationDeactivate(WApplication *wapp)
{
  WScreen *scr = wapp->main_wwin->screen;

  if (wapp->app_icon) {
    wIconSetHighlited(wapp->app_icon->icon, False);
    wAppIconPaint(wapp->app_icon);
  }
  if (wapp->app_menu && wapp->app_menu->flags.mapped) {
    wApplicationMenuHide(wapp->app_menu);
  }

  if (scr->notificationCenter) {
    CFNotificationCenterPostNotification(scr->notificationCenter,
                                         WMDidDeactivateApplicationNotification, wapp, NULL, TRUE);
  }
}

void wApplicationMakeFirst(WApplication *wapp)
{
  WScreen *scr = wapp->main_wwin->screen;
  WApplication *first_wapp;
  /* WApplication *app; */

  if (!scr->wapp_list || !scr->wapp_list->next || wapp == scr->wapp_list)
    return;

  /* Change application list order */
  // connect prev <-> next
  if (wapp->prev)
    wapp->prev->next = wapp->next;
  if (wapp->next)
    wapp->next->prev = wapp->prev;

  // place `wapp` to the first place in wapp_list
  first_wapp = scr->wapp_list;
  first_wapp->prev = wapp;

  wapp->prev = NULL;
  wapp->next = first_wapp;

  scr->wapp_list = wapp;
}

/*---*/

static inline void flushExpose(void)
{
  XEvent tmpev;
  while (XCheckTypedEvent(dpy, Expose, &tmpev)) {
    WMHandleEvent(&tmpev);
  }
  XSync(dpy, 0);
}

static void _hideWindow(WIcon *icon, int icon_x, int icon_y, WWindow *wwin)
{
  if (wwin->flags.miniaturized) {
    if (wwin->icon) {
      XUnmapWindow(dpy, wwin->icon->core->window);
      wwin->icon->mapped = 0;
    }
    wwin->flags.hidden = 1;

    CFMutableDictionaryRef info = CFDictionaryCreateMutable(
        kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryAddValue(info, CFSTR("state"), CFSTR("hide"));
    CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                         WMDidChangeWindowStateNotification, wwin, info, TRUE);
    CFRelease(info);
    return;
  }

  wwin->flags.hidden = 1;
  wWindowUnmap(wwin);

  wClientSetState(wwin, IconicState, icon->icon_win);
  flushExpose();

  wwin->flags.skip_next_animation = 0;

  CFMutableDictionaryRef info = CFDictionaryCreateMutable(
      kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(info, CFSTR("state"), CFSTR("hide"));
  CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                       WMDidChangeWindowStateNotification, wwin, info, TRUE);
  CFRelease(info);
}

void wApplicationHide(WApplication *wapp)
{
  WScreen *scr;
  WWindow *list_wwin;
  int hadfocus;
  Bool wapp_is_workspace = False;

  if (!wapp) {
    WMLogWarning("trying to hide a non grouped window");
    return;
  }
  if (!wapp->main_wwin) {
    WMLogWarning("group leader not found for window group");
    return;
  }

  WMLogWarning("wApplicationHide(%@)", wapp->appName);

  if (wapp->flags.hidden) {
    WMLogWarning("trying to hide already hidden application `%@`", wapp->appName);
    return;
  }

  scr = wapp->main_wwin->screen;
  hadfocus = 0;
  list_wwin = scr->focused_window;
  if (!list_wwin) {
    WMLogWarning("(wmApplicationHide) no focused window for app `%@`", wapp->appName);
    return;
  }

  wapp->flags.skip_next_animation = 1;

  if (list_wwin->main_window == wapp->main_window) {
    wapp->last_focused = list_wwin;
  } else {
    wapp->last_focused = NULL;
  }

  /* Special treatment of Workspace: set focus to main menu prior to any window
     hiding to prevent searching for next focused window. Workspace's main menu
     will not be unmapped on hiding. */
  if (wapp->flags.is_gnustep && !CFStringCompare(wapp->appName, CFSTR("Workspace"), 0)) {
    XSetInputFocus(dpy, wapp->gsmenu_wwin->client_win, RevertToParent, CurrentTime);
    wapp_is_workspace = True;
  }

  // Perform windows hiding
  while (list_wwin) {
    if (list_wwin->main_window == wapp->main_window) {
      if (list_wwin->flags.focused) {
        hadfocus = 1;
      }
      if (wapp->app_icon && (wapp_is_workspace == False || list_wwin != wapp->gsmenu_wwin)) {
        WMLogInfo("Hiding window %lu (%s) of %s", list_wwin->client_win,
                  (WINDOW_LEVEL(list_wwin) == NSMainMenuWindowLevel) ? "menu" : "window",
                  list_wwin->wm_instance);
        _hideWindow(wapp->app_icon->icon, wapp->app_icon->x_pos, wapp->app_icon->y_pos, list_wwin);
      }
    }
    list_wwin = list_wwin->prev;
  }

  wapp->flags.hidden = 1;

  wapp->flags.skip_next_animation = 0;

  if (hadfocus && wapp_is_workspace == False) {
    list_wwin = scr->focused_window;
    // WMLogInfo("(wApplicationHide:) searching for window to focus... focused: %s", scr->focused_window->wm_instance);
    while (list_wwin) {
      if (!WFLAGP(list_wwin, no_focusable) && !list_wwin->flags.hidden &&
          (list_wwin->flags.mapped || list_wwin->flags.shaded)) {
        break;
      }
      list_wwin = list_wwin->prev;
    }
    if (list_wwin) {
      WMLogInfo("(wApplicationHide:) Setting focus to window: %s", list_wwin->wm_instance);
      wSetFocusTo(scr, list_wwin);
    }
  }

  if (wPreferences.auto_arrange_icons) {
    wArrangeIcons(scr, True);
  }
#ifdef HIDDENDOT
  if (wapp->app_icon) {
    wAppIconPaint(wapp->app_icon);
  }
#endif
}

void wApplicationHideOthers(WWindow *wwin)
{
  WWindow *list_wwin;
  WApplication *list_wapp;
  WApplication *wapp;

  if (!wwin) {
    return;
  }
  list_wwin = wwin->screen->focused_window;
  wapp = wApplicationOf(list_wwin->main_window);

  WMLogWarning("wApplicationHideOthers(%@)", wapp->appName);

  while (list_wwin) {
    list_wapp = wApplicationOf(list_wwin->main_window);
    if (list_wapp != wapp && list_wwin->frame->desktop == wwin->screen->current_desktop &&
        !(list_wwin->flags.miniaturized || list_wwin->flags.hidden) &&
        !list_wwin->flags.internal_window) {
      if (list_wapp && list_wwin->main_window != None &&
          list_wwin->main_window != wwin->main_window) {
        if (list_wwin->protocols.HIDE_APP) {
          // Inform client about hiding.
          // Normally WMFHideApplication comes from application (GNUstep) - it's a one call to
          // wApplicationHide() through handleClientMessage() (event.c).
          // In this case we hide app windows on previous line and send client message to draw
          // hidden dot on appicon. This leads to second call to wApplicationHide().
          wClientSendProtocol(list_wwin, w_global.atom.gnustep.wm_hide_app, CurrentTime);
        } else {
          wApplicationHide(list_wapp);
        }
      } else if ((list_wwin->main_window == None || WFLAGP(list_wwin, no_appicon)) &&
                 !WFLAGP(list_wwin, no_miniaturizable)) {
        list_wwin->flags.skip_next_animation = 1;
        wIconifyWindow(list_wwin);
      }
    }
    list_wwin = list_wwin->prev;
  }
}

void wApplicationQuit(WApplication *wapp, Bool force)
{
  CFArrayRef windows = CFArrayCreateCopy(kCFAllocatorDefault, wapp->windows);
  WWindow *wwin;

  for (int i = 0; i < CFArrayGetCount(windows); i++) {
    wwin = (WWindow *)CFArrayGetValueAtIndex(windows, i);
    if (wwin && wwin->protocols.DELETE_WINDOW) {
      wClientSendProtocol(wwin, w_global.atom.wm.delete_window, w_global.timestamp.last_event);
    }
  }

  CFRelease(windows);
}

/* TODO */
/***************************************************************************************************/

void wApplicationForceQuit(WApplication *wapp)
{
  WFakeGroupLeader *fPtr;
  char *buffer;
  char *shortname;

  if (!WCHECK_STATE(WSTATE_NORMAL))
    return;

  WCHANGE_STATE(WSTATE_MODAL);

  shortname = basename(wapp->app_icon->wm_instance);
  fPtr = wapp->main_wwin->fake_group;

  buffer = wstrconcat(wapp->app_icon ? shortname : NULL, _(" will be forcibly closed.\n"
                                                           "Any unsaved changes will be lost.\n"
                                                           "Please confirm."));

  wretain(wapp->main_wwin);
  dispatch_async(workspace_q, ^{
    if (wPreferences.dont_confirm_kill ||
        WSRunAlertPanel(_("Kill Application"), buffer, _("Keep Running"), _("Kill"), NULL) ==
            NSAlertAlternateReturn) {
      if (fPtr != NULL) {
        WWindow *wwin, *twin;

        wwin = wapp->main_wwin->screen->focused_window;
        while (wwin) {
          twin = wwin->prev;
          if (wwin->fake_group == fPtr)
            wClientKill(wwin);
          wwin = twin;
        }
      } else if (!wapp->main_wwin->flags.destroyed) {
        wClientKill(wapp->main_wwin);
      }
    }
    wrelease(wapp->main_wwin);
    wfree(buffer);
    WCHANGE_STATE(WSTATE_NORMAL);
  });
}
