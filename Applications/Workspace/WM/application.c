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
#include "workspace.h"
#include "dock.h"
#include "defaults.h"
#include "startup.h"
#include "actions.h"

#ifdef NEXTSPACE
#include <Workspace+WM.h>
#include "framewin.h"
#include "appmenu.h"
#endif

/******** Notification observers ********/

static void postWorkspaceNotification(WWindow *wwin, CFStringRef name)
{
  CFMutableDictionaryRef info;
  CFNumberRef windowID;
  CFStringRef appName;
  
  if (wwin->screen->notificationCenter) {
    info = CFDictionaryCreateMutable(kCFAllocatorDefault, 2,
                                     &kCFTypeDictionaryKeyCallBacks,
                                     &kCFTypeDictionaryValueCallBacks);
    windowID = CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &wwin->client_win);
    CFDictionaryAddValue(info, CFSTR("WindowID"), windowID);
    appName = CFStringCreateWithCString(kCFAllocatorDefault, wwin->wm_class,
                                        CFStringGetSystemEncoding());
    CFDictionaryAddValue(info, CFSTR("ApplicationName"), appName);

    CFNotificationCenterPostNotification(wwin->screen->notificationCenter, name,
                                         CFSTR("GSWorkspaceNotification"),
                                         info, TRUE);
    CFRelease(windowID);
    CFRelease(appName);
    CFRelease(info);
  }
}

static void shadeObserver(CFNotificationCenterRef center,
                          void *wobserver,     // wapp
                          CFNotificationName name,
                          const void *object,      // object - ignored
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
      WMLogInfo("WM wapp %s received foreing notification",
                observer_wapp->main_wwin->wm_instance);
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

static void hideOthersObserver(CFNotificationCenterRef center,
                            void *wobserver,     // wapp
                            CFNotificationName name,
                            const void *object,      // object - ignored
                            CFDictionaryRef userInfo)
{
  CFNumberRef windowID = CFDictionaryGetValue(userInfo, CFSTR("WindowID"));
  /* WApplication *observer_wapp = (WApplication *)wobserver; */
  /* WApplication *wapp; */
  Window window = 0;
  WWindow *wwin;

  if (windowID) {
    WMLogInfo("Will hide other applications for window %lu", window);
    CFNumberGetValue(windowID, kCFNumberLongType, &window);
    wwin = wWindowFor(window);
    wHideOtherApplications(wwin);
    postWorkspaceNotification(wwin, WMDidHideOthersNotification);
  }
}


static WWindow *makeMainWindow(WScreen * scr, Window window)
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
  if (XFindContext(dpy, window, w_global.context.app_win, (XPointer *) & wapp) != XCSUCCESS)
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
  
  WMLogInfo("ADD window: %lu level:%i name: %s refcount=%i",
           wwin->client_win, window_level, wwin->wm_instance, wapp->refcount);
  
  if (wapp->app_icon && wapp->app_icon->docked &&
      wapp->app_icon->relaunching && wapp->main_wwin->fake_group) {
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

  WMLogInfo("REMOVE window: %lu name: %s WApplication refcount=%i",
           wwin->client_win, wwin->wm_instance, wapp->refcount);
  
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

WApplication *wApplicationCreate(WWindow * wwin)
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

  WMLogInfo("CREATE for window: %lu level:%i name: %s",
           wwin->client_win, WINDOW_LEVEL(wwin), wwin->wm_instance);

  wapp = wmalloc(sizeof(WApplication));

  wapp->windows = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);

  wapp->refcount = 1;
  wapp->last_focused = wwin;
  wapp->urgent_bounce_timer = NULL;
  wapp->gsmenu_wwin = NULL;
  wapp->flags.is_gnustep = wwin->flags.is_gnustep;
  if (wwin->flags.is_gnustep) {
    wapp->appName = CFStringCreateWithCString(kCFAllocatorDefault, wwin->wm_instance,
                                              kCFStringEncodingUTF8);
  } else {
    wapp->appName = CFStringCreateWithCString(kCFAllocatorDefault, wwin->wm_class,
                                              kCFStringEncodingUTF8);
  }
  /* wapp->app_name = wwin->flags.is_gnustep ? wstrdup(wwin->wm_instance) : wstrdup(wwin->wm_class); */

  wApplicationAddWindow(wapp, wwin);
  
  wapp->last_workspace = wwin->screen->current_workspace;

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
  XSaveContext(dpy, main_window, w_global.context.app_win, (XPointer) wapp);

  create_appicon_for_application(wapp, wwin);

  /* Application menu */
  if (!wapp->flags.is_gnustep) {
    wapp->app_menu = wApplicationMenuCreate(scr, wapp);
    wapp->appState = (CFMutableDictionaryRef)WMUserDefaultsRead(wapp->appName, false);
    if (wapp->appState) {
      CFRetain(wapp->appState);
      wapp->menus_state = (CFMutableArrayRef)CFDictionaryGetValue(wapp->appState, CFSTR("MenusState"));
    }
  }

  if (!scr->wapp_list) {
    scr->wapp_list = wapp;
    wapp->prev = NULL;
    wapp->next = NULL;
  }
  else {
    WApplication *wa = scr->wapp_list;
    while (wa->next)
      wa = wa->next;
    wa->next = wapp;
    wapp->prev = wa;
    wapp->next = NULL;
    wApplicationMakeFirst(wapp);
  }

  WMLogInfo("WApplication `%s` was created! Prev `%s` Next `%s`",
           wwin->wm_instance,
           wapp->prev ? wapp->prev->main_wwin->wm_instance : "NULL",
           wapp->next ? wapp->next->main_wwin->wm_instance : "NULL");
        
  if (scr->notificationCenter) {
    CFNotificationCenterAddObserver(scr->notificationCenter, wapp, shadeObserver,
                                    WMShouldShadeWindowNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(scr->notificationCenter, wapp, hideOthersObserver,
                                    WMShouldHideOthersNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
  
    // Notify Workspace's ProcessManager
    CFNotificationCenterPostNotification(scr->notificationCenter,
                                         WMDidCreateApplicationNotification,
                                         wapp, NULL, TRUE);
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

  WMLogInfo("DESTROY main window:%lu name:%s windows #:%li refcount:%i",
           wapp->main_window, wapp->app_icon->wm_instance,
           CFArrayGetCount(wapp->windows), wapp->refcount);

  wapp->refcount--;
  if (wapp->refcount > 0)
    return;

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

  scr = wapp->main_wwin->screen;
  
  // Notify Workspace's ProcessManager
  CFNotificationCenterPostNotification(scr->notificationCenter,
                                       WMDidDestroyApplicationNotification, wapp, NULL, TRUE);

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
                 (XPointer) & wwin->client_descriptor);
  }

  wfree(wapp);
  wapp = NULL;
  WMLogInfo("DESTROY END.");
}

void wApplicationActivate(WApplication *wapp)
{
  WScreen *scr = wapp->main_wwin->screen;

  WMLogInfo("wApplicationActivate %s current WS:%i last WS:%i app WS:%i",
           wapp->main_wwin->wm_instance,
           scr->current_workspace, scr->last_workspace,
           wapp->last_workspace);
  
  if (wapp->last_workspace != scr->current_workspace &&
      scr->last_workspace == scr->current_workspace) {
    wWorkspaceChange(scr, wapp->last_workspace, NULL);
  }
  
  wApplicationMakeFirst(wapp);
  
  if (wapp->menus_state && !wapp->app_menu->flags.restored) {
    wApplicationMenuRestoreFromState(wapp->app_menu, wapp->menus_state);
    wapp->app_menu->flags.restored = 1;
  } else {
    wApplicationMenuShow(wapp->app_menu);
  }
  
  if (!wapp->appState) {
    wapp->appState = CFDictionaryCreateMutable(kCFAllocatorDefault, 1,
                                               &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
  }
}

void wApplicationDeactivate(WApplication *wapp)
{
  if (wapp->app_icon) {
    wIconSetHighlited(wapp->app_icon->icon, False);
    wAppIconPaint(wapp->app_icon);
  }
  if (wapp->app_menu && wapp->app_menu->flags.mapped) {
    wApplicationMenuHide(wapp->app_menu);
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
