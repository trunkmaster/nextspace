/*
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


#ifndef __WORKSPACE_WM_APPLICATION__
#define __WORKSPACE_WM_APPLICATION__

#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFDictionary.h>
#include <CoreFoundation/CFRunLoop.h>

#include <X11/X.h>
#include <X11/Xproto.h>

#include "menu.h"

/* for tracking single application instances */
typedef struct WApplication {
  struct WApplication *next;
  struct WApplication *prev;

  int refcount;

  CFStringRef appName;
  CFMutableDictionaryRef appState;

  Window main_window;               /* ID of the group leader */
  struct WWindow *main_wwin;        /* main (leader) window */
  struct WAppIcon *app_icon;
  struct WWindow *last_focused;     /* focused window before hide or switch to other */
  int last_desktop;                 /* last workspace the app used to work on */
  
  CFMutableArrayRef windows;
  struct WWindow *gsmenu_wwin;      /* GNUstep application menu window */
  WMenu *app_menu;                  /* application menu */
  CFMutableArrayRef menus_state;    /* live menu state info */

  CFRunLoopTimerRef urgent_bounce_timer;
  struct {
    unsigned int is_gnustep : 1;
    unsigned int skip_next_animation : 1;
    unsigned int hidden : 1;
    unsigned int emulated : 1;
    unsigned int bouncing : 1;
  } flags;

} WApplication;

void wApplicationAddWindow(WApplication *wapp, struct WWindow *wwin);
void wApplicationRemoveWindow(WApplication *wapp, struct WWindow *wwin);

WApplication *wApplicationCreate(struct WWindow *wwin);
WApplication *wApplicationWithName(WScreen *scr, char *app_name);
WApplication *wApplicationOf(Window window);
WApplication *wApplicationForWindow(struct WWindow *wwin);
void wApplicationDestroy(WApplication *wapp);

void wAppBounce(WApplication *);
void wAppBounceWhileUrgent(WApplication *);
void wApplicationActivate(WApplication *);
void wApplicationDeactivate(WApplication *);

void wApplicationMakeFirst(WApplication *);

void wApplicationHide(WApplication *wapp);
void wApplicationHideOthers(struct WWindow *awin);
void wApplicationQuit(WApplication *wapp, Bool force);

#endif /* __WORKSPACE_WM_APPLICATION__ */
