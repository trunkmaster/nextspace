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

#include "WM.h"

#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <string.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <core/log_utils.h>

#include "WM.h"
#include "window.h"
#include "framewin.h"
#include "client.h"
#include "properties.h"
#include "session.h"
#include "wmspec.h"
#include "colormap.h"
#include "shutdown.h"

#import <Workspace+WM.h>

/*
 *----------------------------------------------------------------------
 * wipeDesktop--
 * 	Kills all windows in a screen. Send DeleteWindow to all windows
 * that support it and KillClient on all windows that don't.
 *
 * Side effects:
 * 	All managed windows are closed.
 *
 * TODO: change to XQueryTree()
 *----------------------------------------------------------------------
 */
static void _wipeDesktop(WScreen *scr)
{
  WWindow *wwin;

  wwin = scr->focused_window;
  while (wwin) {
    // Do not kill Workspace menu
    if (WINDOW_LEVEL(wwin) != NSMainMenuWindowLevel) {
      if (wwin->protocols.DELETE_WINDOW) {
        wClientSendProtocol(wwin, w_global.atom.wm.delete_window, w_global.timestamp.last_event);
      } else {
        wClientKill(wwin);
      }
    }
    wwin = wwin->prev;
  }
  XSync(dpy, False);
}

/*
 *----------------------------------------------------------------------
 * Shutdown-
 * 	Exits the window manager cleanly. If mode is WSLogoutMode,
 * the whole X session will be closed, by killing all clients if
 * no session manager is running or by asking a shutdown to
 * it if its present.
 *
 *----------------------------------------------------------------------
 */
void wShutdown(WMShutdownMode mode)
{
  WScreen *scr;

#ifdef HAVE_INOTIFY
  if (w_global.inotify.fd_event_queue >= 0) {
    close(w_global.inotify.fd_event_queue);
    w_global.inotify.fd_event_queue = -1;
  }
#endif

  scr = wDefaultScreen();
  if (!scr) {
    return;
  }

  switch (mode) {
    case WMExitMode:
      CFRelease(scr->notificationCenter);
      scr->notificationCenter = NULL;

      // Stop events processing inside Window Decorator
      CFRunLoopStop(wm_runloop);
      WCHANGE_STATE(WSTATE_EXITING);

      wScreenSaveState(scr);
      wNETWMCleanup(scr);         /* Delete _NET_* Atoms */
      PropCleanUp(scr->root_win); /* WM specific properties */
      RShutdown();                /* wraster clean exit */
#if HAVE_SYSLOG_H
      WMSyslogClose();
#endif
      _wipeDesktop(scr);
      CFRelease(scr->launching_icons);
      break;

    case WMRestartMode:
      wScreenSaveState(scr);
      wRestoreDesktop(scr);
      break;
  }
}

static void _restoreWindows(WMBag *bag, WMBagIterator iter)
{
  WCoreWindow *next;
  WCoreWindow *core;
  WWindow *wwin;

  if (iter == NULL) {
    core = WMBagFirst(bag, &iter);
  } else {
    core = WMBagNext(bag, &iter);
  }

  if (core == NULL)
    return;

  _restoreWindows(bag, iter);

  /* go to the end of the list */
  while (core->stacking->under)
    core = core->stacking->under;

  while (core) {
    next = core->stacking->above;

    if (core->descriptor.parent_type == WCLASS_WINDOW) {
      Window window;

      wwin = core->descriptor.parent;
      window = wwin->client_win;
      wUnmanageWindow(wwin, !wwin->flags.internal_window, False);
      XMapWindow(dpy, window);
    }
    core = next;
  }
}

/*
 *----------------------------------------------------------------------
 * RestoreDesktop--
 * 	Puts the desktop in a usable state when exiting.
 *
 * Side effects:
 * 	All frame windows are removed and windows are reparented
 * back to root. Windows that are outside the screen are
 * brought to a viable place.
 *
 *----------------------------------------------------------------------
 */
void wRestoreDesktop(WScreen *scr)
{
  XGrabServer(dpy);

  /* reparent windows back to the root window, keeping the stacking order */
  _restoreWindows(scr->stacking_list, NULL);

  XUngrabServer(dpy);
  XSetInputFocus(dpy, PointerRoot, RevertToParent, CurrentTime);
  wColormapInstallForWindow(scr, NULL);
  PropCleanUp(scr->root_win);
  wNETWMCleanup(scr);
  XSync(dpy, 0);
}
