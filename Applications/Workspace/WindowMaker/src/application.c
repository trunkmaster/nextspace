/*
 *  Window Maker window manager
 *
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
#include "wconfig.h"

#include <X11/Xlib.h>
#include <string.h>

#include "WindowMaker.h"
#include "menu.h"
#include "window.h"
#ifdef USER_MENU
#include "usermenu.h"
#endif				/* USER_MENU */
#include "appicon.h"
#include "application.h"
#include "appmenu.h"
#include "properties.h"
#include "workspace.h"
#include "dock.h"
#include "defaults.h"

#ifdef NEXTSPACE
#include <Workspace+WindowMaker.h>
#include <stdio.h>
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

void wApplicationPrintWindowList(WApplication *wapp)
{
  WMArray *window_list = wapp->windows;
  int window_count = WMGetArrayItemCount(window_list);
  WWindow *wwin;
  char *window_type = NULL;

  fprintf(stderr, "[WM] window list of application: %s\n", wapp->app_icon->wm_instance);
  for (int i = 0; i < window_count; i++) {
    wwin = WMGetFromArray(window_list, i);
    if (wwin) {
      switch (WINDOW_LEVEL(wwin)) {
      case WMNormalLevel:
        window_type = "Normal";
        break;
      case WMFloatingLevel:
        window_type = "Floating";
        break;
      case WMDockLevel:
        window_type = "Dock";
        break;
      case WMSubmenuLevel:
        window_type = "Submenu";
        break;
      case WMMainMenuLevel:
        window_type = "Main Menu";
        break;
      case WMStatusLevel:
        window_type = "Status";
        break;
      case WMModalLevel:
        window_type = "Modal";
        break;
      case WMPopUpLevel:
        window_type = "PopUp";
        break;
      default:
        window_type = "Unknown";
      }
      fprintf(stderr, "\tID: %lu Type: %s\n", wwin->client_win, window_type);
    }
  }
}

BOOL _isWindowAlreadyRegistered(WApplication *wapp, WWindow *wwin)
{
  return True;
}

/* 
   New functionality: GNUstep applications special handling.

   On application start wApplicationCreate() is called:
   - creates wapp->windows array
   - adds `wwin` to this array
   - saved `wwin` to `wapp->menu_win` if it's main menu (normally it is)

   When new window opens (MapRequest, MapNotify) wApplicationAdd() is called:
   - adds `wwin` into `wapp->windows` array
   - wapp->refcount++

   When window is closed (UnmapNotify) and window is not main menu
   wApplicationRemoveWindow() is called:
   - removes `wwin` from `wapp->windows` array
   - wapp->refcount--

   When application quits (DestroyNotify):
   - several calls to wApplicationRemoveWindow() is performed
   - wApplicationDestroy() is called:
     - wUnmanageWindow for wapp->menu_win is called
     - wapp->windows array destroyed
     - wapp->refcount--
     - `wapp` is freed
*/

void wApplicationAddWindow(WApplication *wapp, WWindow *wwin)
{
  int window_level = WINDOW_LEVEL(wwin);
  
  fprintf(stderr, "[WM wApplication] ADD window: %lu level:%i name: %s refcount=%i\n",
          wwin->client_win, window_level, wwin->wm_instance, wapp->refcount);
  
  if (wapp->app_icon && wapp->app_icon->docked &&
      wapp->app_icon->relaunching && wapp->main_window_desc->fake_group) {
    wDockFinishLaunch(wapp->app_icon);
  }

  if (window_level == WMMainMenuLevel) {
    wapp->menu_win = wwin;
  }
  
  /* Do not add short-living objects to window list: tooltips, submenus, popups, etc. */
  if (window_level != WMNormalLevel && window_level != WMFloatingLevel) {
    return;
  }

  WMAddToArray(wapp->windows, wwin);
  wapp->refcount++;
  
  /* wApplicationPrintWindowList(wapp); */
  
#ifdef NEXTSPACE
  dispatch_sync(workspace_q, ^{ XWApplicationDidAddWindow(wapp, wwin); });
#endif                
}

void wApplicationRemoveWindow(WApplication *wapp, WWindow *wwin)
{
  int window_count = WMGetArrayItemCount(wapp->windows);
  WWindow *awin;

  fprintf(stderr, "[WM wApplication] REMOVE window: %lu name: %s refcount=%i\n",
          wwin->client_win, wwin->wm_instance, wapp->refcount);
  
  for (int i = 0; i < window_count; i++) {
    awin = WMGetFromArray(wapp->windows, i);
    if (awin == wwin) {
      WMDeleteFromArray(wapp->windows, i);
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

  fprintf(stderr, "[WM wApplication] CREATE for window: %lu level:%i name: %s\n",
          wwin->client_win, WINDOW_LEVEL(wwin), wwin->wm_instance);

	wapp = wmalloc(sizeof(WApplication));

  wapp->windows = WMCreateArray(1);
  wApplicationAddWindow(wapp, wwin);

  wapp->flags.is_gnustep = wwin->flags.is_gnustep;
	wapp->refcount = 1;
	wapp->last_focused = NULL;
	wapp->urgent_bounce_timer = NULL;

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

	wapp->menu = wAppMenuGet(scr, main_window);
#ifdef USER_MENU
	if (!wapp->menu)
		wapp->menu = wUserMenuGet(scr, wapp->main_window_desc);
#endif

	/* Set application wide attributes from the leader */
	wapp->flags.hidden = WFLAGP(wapp->main_window_desc, start_hidden);
	wapp->flags.emulated = WFLAGP(wapp->main_window_desc, emulate_appicon);

	/* application descriptor */
	XSaveContext(dpy, main_window, w_global.context.app_win, (XPointer) wapp);

	create_appicon_for_application(wapp, wwin);

#ifdef NEXTSPACE
	dispatch_sync(workspace_q, ^{ XWApplicationDidCreate(wapp, wwin); });
#endif

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

  fprintf(stderr, "[WM] WApplication `%s` was created! Prev `%s` Next `%s`\n",
          wwin->wm_instance,
          wapp->prev ? wapp->prev->main_window_desc->wm_instance : "NULL",
          wapp->next ? wapp->next->main_window_desc->wm_instance : "NULL");
        
	return wapp;
}

void wApplicationDestroy(WApplication *wapp)
{
	WWindow *wwin;
	WScreen *scr;

	if (!wapp)
		return;

  fprintf(stderr, "[WM application.c] DESTROY main window:%lu name:%s windows #:%i refcount:%i\n",
          wapp->main_window, wapp->app_icon->wm_instance,
          WMGetArrayItemCount(wapp->windows), wapp->refcount);

  WMEmptyArray(wapp->windows);
  WMFreeArray(wapp->windows);
  
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
	dispatch_sync(workspace_q, ^{ XWApplicationDidDestroy(wapp); });
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
	wAppMenuDestroy(wapp->menu);

	/* Remove application icon */
	removeAppIconFor(wapp);

	wwin = wWindowFor(wapp->main_window_desc->client_win);

	wWindowDestroy(wapp->main_window_desc);
	if (wwin) {
		/* undelete client window context that was deleted in
		 * wWindowDestroy */
		XSaveContext(dpy, wwin->client_win, w_global.context.client_win, (XPointer) & wwin->client_descriptor);
	}
	wfree(wapp);
  fprintf(stderr, "[WM application.c] DESTROY END.\n");
}

void wApplicationActivate(WApplication *wapp)
{
  WScreen *scr = wapp->main_window_desc->screen_ptr;

  fprintf(stderr, "[WM] wApplicationActivate %s current WS:%i last WS:%i app WS:%i\n",
          wapp->main_window_desc->wm_instance,
          scr->current_workspace, scr->last_workspace,
          wapp->last_workspace);
  
	if (wapp->app_icon && wPreferences.highlight_active_app) {
		wIconSetHighlited(wapp->app_icon->icon, True);
		wAppIconPaint(wapp->app_icon);
	}
  
  if (wapp->last_workspace != scr->current_workspace &&
      scr->last_workspace == scr->current_workspace) {
    if (wapp->last_focused) {
      wWorkspaceSaveFocusedWindow(scr, wapp->last_workspace, wapp->last_focused);
    }
    wWorkspaceChange(scr, wapp->last_workspace);
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
  WApplication *first_wapp, *app;
  
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
  fprintf(stderr, "[WM] wApplicationMakeFirst: %s. Application list:",
          wapp->main_window_desc->wm_instance);

  app = scr->wapp_list;
  while (app) {
    fprintf(stderr, ", %s", app->main_window_desc->wm_instance);
    app = app->next;
  }
  fprintf(stderr, "\n");
}
