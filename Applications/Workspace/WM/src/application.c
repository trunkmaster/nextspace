/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1998-2003 Dan Pascu
 *  Copyright (c) 2015-2018 Sergii Stoian
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

#include <X11/Xlib.h>
#include <string.h>

#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFLogUtilities.h>

#include <WMcore/memory.h>
#include <WMcore/handlers.h>

#include "GNUstep.h"
#include "WindowMaker.h"
#include "menu.h"
#include "window.h"
#include "appicon.h"
#include "application.h"
#include "properties.h"
#include "workspace.h"
#include "dock.h"
#include "defaults.h"

#ifdef NEXTSPACE
#include <Workspace+WM.h>
#include "framewin.h"
#endif

/******** Local variables ********/

static WWindow *makeMainWindow(WScreen * scr, Window window)
{
  WWindow *wwin;
  XWindowAttributes attr;

  if (!XGetWindowAttributes(dpy, window, &attr))
    return NULL;

  wwin = wWindowCreate();
  wwin->screen_ptr = scr;
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

BOOL _isWindowAlreadyRegistered(WApplication *wapp, WWindow *wwin)
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
  
  wmessage("[application.c] ADD window: %lu level:%i name: %s refcount=%i\n",
           wwin->client_win, window_level, wwin->wm_instance, wapp->refcount);
  
  if (wapp->app_icon && wapp->app_icon->docked &&
      wapp->app_icon->relaunching && wapp->main_window_desc->fake_group) {
    wDockFinishLaunch(wapp->app_icon);
  }

  if (_isWindowAlreadyRegistered(wapp, wwin))
    return;

  if (window_level == NSMainMenuWindowLevel)
    wapp->menu_win = wwin;
  
  /* Do not add short-living objects to window list: tooltips, submenus, popups, etc. */
  if (window_level != NSNormalWindowLevel && window_level != NSFloatingWindowLevel)
    return;

  CFArrayAppendValue(wapp->windows, wwin);
  wapp->refcount++;
  
#ifdef NEXTSPACE
  dispatch_sync(workspace_q, ^{ WSApplicationDidAddWindow(wapp, wwin); });
#endif                
}

void wApplicationRemoveWindow(WApplication *wapp, WWindow *wwin)
{
  int window_count;
  WWindow *awin;

  /* Application could be already destryed */
  if (wapp == NULL || wapp->windows == NULL || wwin == NULL)
    return;

  window_count = CFArrayGetCount(wapp->windows);

  wmessage("[application.c] REMOVE window: %lu name: %s refcount=%i\n",
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
  WScreen *scr = wwin->screen_ptr;
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

  wmessage("[application.c] CREATE for window: %lu level:%i name: %s\n",
           wwin->client_win, WINDOW_LEVEL(wwin), wwin->wm_instance);

  wapp = wmalloc(sizeof(WApplication));

  wapp->windows = CFArrayCreateMutable(NULL, 1, NULL);

  wapp->refcount = 1;
  wapp->last_focused = wwin;
  wapp->urgent_bounce_timer = NULL;
  wapp->menu_win = NULL;
  wapp->flags.is_gnustep = wwin->flags.is_gnustep;

  wApplicationAddWindow(wapp, wwin);
  
  wapp->last_workspace = wwin->screen_ptr->current_workspace;

  wapp->main_window = main_window;
  wapp->main_window_desc = makeMainWindow(scr, main_window);
  if (!wapp->main_window_desc) {
    wfree(wapp);
    return NULL;
  }

  wapp->main_window_desc->fake_group = wwin->fake_group;
  wapp->main_window_desc->net_icon_image = RRetainImage(wwin->net_icon_image);

  leader = wWindowFor(main_window);
  if (leader)
    leader->main_window = main_window;

  /* Set application wide attributes from the leader */
  wapp->flags.hidden = WFLAGP(wapp->main_window_desc, start_hidden);
  wapp->flags.emulated = WFLAGP(wapp->main_window_desc, emulate_appicon);

  /* application descriptor */
  XSaveContext(dpy, main_window, w_global.context.app_win, (XPointer) wapp);

  create_appicon_for_application(wapp, wwin);

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

  wmessage("[application.c] WApplication `%s` was created! Prev `%s` Next `%s`\n",
           wwin->wm_instance,
           wapp->prev ? wapp->prev->main_window_desc->wm_instance : "NULL",
           wapp->next ? wapp->next->main_window_desc->wm_instance : "NULL");
        
#ifdef NEXTSPACE
  dispatch_sync(workspace_q, ^{ WSApplicationDidCreate(wapp, wwin); });
#endif

  return wapp;
}

WApplication *wApplicationWithName(WScreen *scr, char *app_name)
{
  WApplication *app = scr ? scr->wapp_list : wDefaultScreen()->wapp_list;
  
  while (app) {
    if (!strcmp(app->main_window_desc->wm_instance, app_name))
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

  wmessage("[application.c] DESTROY main window:%lu name:%s windows #:%i refcount:%i\n",
           wapp->main_window, wapp->app_icon->wm_instance,
           CFArrayGetCount(wapp->windows), wapp->refcount);

  CFShow(wapp->windows);
  CFArrayRemoveAllValues(wapp->windows);
  CFRelease(wapp->windows);
  CFLog(kCFLogLevelError,
        CFSTR("wapp->windows retain count: %i"), CFGetRetainCount(wapp->windows));

  wapp->refcount--;
  
  if (wapp->refcount > 0)
    return;

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

#ifdef NEXTSPACE
  // Must be synchronous. Otherwise XWApplicationDidDestroy crashed
  // during access to wapp structure.
  dispatch_sync(workspace_q, ^{ WSApplicationDidDestroy(wapp); });
#endif
        
  scr = wapp->main_window_desc->screen_ptr;

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

  wwin = wWindowFor(wapp->main_window_desc->client_win);

  wWindowDestroy(wapp->main_window_desc);
  if (wwin) {
    /* undelete client window context that was deleted in
     * wWindowDestroy */
    XSaveContext(dpy, wwin->client_win, w_global.context.client_win,
                 (XPointer) & wwin->client_descriptor);
  }

  wfree(wapp);
  wmessage("[application.c] DESTROY END.\n");
}

void wApplicationActivate(WApplication *wapp)
{
  WScreen *scr = wapp->main_window_desc->screen_ptr;

  wmessage("[application.c] wApplicationActivate %s current WS:%i last WS:%i app WS:%i\n",
           wapp->main_window_desc->wm_instance,
           scr->current_workspace, scr->last_workspace,
           wapp->last_workspace);
  
  if (wapp->last_workspace != scr->current_workspace &&
      scr->last_workspace == scr->current_workspace) {
    wWorkspaceChange(scr, wapp->last_workspace, NULL);
  }
  wApplicationMakeFirst(wapp);
}

void wApplicationDeactivate(WApplication *wapp)
{
  if (wapp->app_icon) {
    wIconSetHighlited(wapp->app_icon->icon, False);
    wAppIconPaint(wapp->app_icon);
  }
}

void wApplicationMakeFirst(WApplication *wapp)
{
  WScreen *scr = wapp->main_window_desc->screen_ptr;
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

  /* wmessage("[application.c] wApplicationMakeFirst: %s. Application list: ", */
  /*          wapp->main_window_desc->wm_instance); */
  /* app = scr->wapp_list; */
  /* while (app) { */
  /*   wmessage("%s%s", app->main_window_desc->wm_instance, app->next ? ", " : ""); */
  /*   app = app->next; */
  /* } */
}
