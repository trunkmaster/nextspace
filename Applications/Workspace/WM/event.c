/*  Event loop and events handling
 *
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2014 Window Maker Team
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
#include <unistd.h>
#include <string.h>
#include <strings.h>
#include <time.h>
#include <errno.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#ifdef USE_XSHAPE
#include <X11/extensions/shape.h>
#endif
#ifdef USE_DOCK_XDND
#include "xdnd.h"
#endif

#ifdef USE_XKB
#include <X11/XKBlib.h>
#endif /* USE_XKB */

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFFileDescriptor.h>

#include <core/util.h>
#include <core/log_utils.h>
#include <core/wevent.h>
#include <core/drawing.h>
#include <core/wuserdefaults.h>

#include "GNUstep.h"
#include "WM.h"
#include "window.h"
#include "actions.h"
#include "client.h"
#include "switchpanel.h"
#include "application.h"
#include "stacking.h"
#include "defaults.h"
#include "desktop.h"
#include "dock.h"
#include "framewin.h"
#include "properties.h"
#include "balloon.h"
#include "xrandr.h"
#include "wmspec.h"
#include "colormap.h"
#include "screen.h"
#include "shutdown.h"
#include "misc.h"
#include "event.h"
#include "winmenu.h"
#include "switchmenu.h"
#include "iconyard.h"
#include "application.h"
#include "appmenu.h"

#include <Workspace+WM.h>
extern void wIconYardShowIcons(WScreen *screen);
extern void wIconYardHideIcons(WScreen *screen);

#define ALT_MOD_MASK wPreferences.alt_modifier_mask

/************ Local stuff ***********/

static void saveTimestamp(XEvent *event);
static void handleColormapNotify(XEvent *event);
static void handleMapNotify(XEvent *event);
static void handleUnmapNotify(XEvent *event);
static void handleButtonPress(XEvent *event);
static void handleButtonRelease(XEvent *event); /* NEXTSPACE */
static void handleKeyRelease(XEvent *event);    /* NEXTSPACE */
static void handleExpose(XEvent *event);
static void handleDestroyNotify(XEvent *event);
static void handleConfigureRequest(XEvent *event);
static void handleMapRequest(XEvent *event);
static void handlePropertyNotify(XEvent *event);
static void handleEnterNotify(XEvent *event);
static void handleLeaveNotify(XEvent *event);
static void handleExtensions(XEvent *event);
static void handleClientMessage(XEvent *event);
static void handleKeyPress(XEvent *event);
static void handleFocusIn(XEvent *event);
static void handleMotionNotify(XEvent *event);
static void handleVisibilityNotify(XEvent *event);
static void handle_selection_request(XSelectionRequestEvent *event);
static void handle_selection_clear(XSelectionClearEvent *event);
static void wdelete_death_handler(WMagicNumber id);

#ifdef USE_XSHAPE
static void handleShapeNotify(XEvent *event);
#endif

#ifdef USE_XKB
static void handleXkbBellNotify(XkbEvent *event);
static void handleXkbStateNotify(XkbEvent *event);
#endif

/* real dead process handler */
static void handleDeadProcess(void);

typedef struct DeadProcesses {
  pid_t pid;
  unsigned char exit_status;
} DeadProcesses;

/* stack of dead processes */
static DeadProcesses deadProcesses[MAX_DEAD_PROCESSES];
static int deadProcessPtr = 0;

typedef struct DeathHandler {
  WDeathHandler *callback;
  pid_t pid;
  void *client_data;
} DeathHandler;

static CFMutableArrayRef deathHandlers = NULL;

WMagicNumber wAddDeathHandler(pid_t pid, WDeathHandler *callback, void *cdata)
{
  DeathHandler *handler;

  handler = malloc(sizeof(DeathHandler));
  if (!handler)
    return 0;

  handler->pid = pid;
  handler->callback = callback;
  handler->client_data = cdata;

  if (!deathHandlers)
    deathHandlers = CFArrayCreateMutable(kCFAllocatorDefault, 8, NULL);

  CFArrayAppendValue(deathHandlers, handler);

  return handler;
}

static void wdelete_death_handler(WMagicNumber id)
{
  DeathHandler *handler = (DeathHandler *)id;
  CFIndex idx;

  if (!handler || !deathHandlers)
    return;

  idx = CFArrayGetFirstIndexOfValue(deathHandlers, CFRangeMake(0, CFArrayGetCount(deathHandlers)),
                                    handler);
  if (idx != kCFNotFound) {
    CFArrayRemoveValueAtIndex(deathHandlers, idx);
    free(handler);
  }
}

void DispatchEvent(XEvent *event)
{
  if (deathHandlers)
    handleDeadProcess();

  if (WCHECK_STATE(WSTATE_NEED_EXIT) || WCHECK_STATE(WSTATE_EXITING)) {
    /* WCHANGE_STATE(WSTATE_EXITING); */
    /* WMHandleEvent() can't be called from anything
     * executed inside here, or we can get in a infinite
     * recursive loop. */
    return;
  } else if (WCHECK_STATE(WSTATE_NEED_RESTART)) {
    WCHANGE_STATE(WSTATE_RESTARTING);
    return;
    /* wShutdown(WMRestartMode); */
  } else if (WCHECK_STATE(WSTATE_NEED_REREAD)) {
    WCHANGE_STATE(WSTATE_NORMAL);
    wDefaultsUpdateDomainsIfNeeded(NULL);
  }

  /* for the case that all that is wanted to be dispatched is
   * the stuff above */
  if (!event)
    return;

  saveTimestamp(event);
  switch (event->type) {
    case MapRequest:
      handleMapRequest(event);
      break;

    case KeyPress:
      handleKeyPress(event);
      break;

    case KeyRelease:
      handleKeyRelease(event);
      break;

    case MotionNotify:
      handleMotionNotify(event);
      break;

    case ConfigureRequest:
      handleConfigureRequest(event);
      break;

    case DestroyNotify:
      handleDestroyNotify(event);
      break;

    case MapNotify:
      handleMapNotify(event);
      break;

    case UnmapNotify:
      handleUnmapNotify(event);
      break;

    case ButtonPress:
      handleButtonPress(event);
      break;

    case Expose:
      handleExpose(event);
      break;

    case ButtonRelease:
      handleButtonRelease(event);
      break;

    case PropertyNotify:
      handlePropertyNotify(event);
      break;

    case EnterNotify:
      handleEnterNotify(event);
      break;

    case LeaveNotify:
      handleLeaveNotify(event);
      break;

    case ClientMessage:
      handleClientMessage(event);
      break;

    case ColormapNotify:
      handleColormapNotify(event);
      break;

    case MappingNotify:
      if (event->xmapping.request == MappingKeyboard || event->xmapping.request == MappingModifier)
        XRefreshKeyboardMapping(&event->xmapping);
      break;

    case FocusIn:
      handleFocusIn(event);
      break;

    case VisibilityNotify:
      handleVisibilityNotify(event);
      break;

    case ConfigureNotify:
      break;

    case SelectionRequest:
      handle_selection_request(&event->xselectionrequest);
      break;

    case SelectionClear:
      handle_selection_clear(&event->xselectionclear);
      break;

    default:
      handleExtensions(event);
      break;
  }
}

static void _runLoopHandleEvent(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info)
{
  XEvent event;

  /* WMLogError("1. _processXEvent() - %i", XPending(dpy)); */
  while (XPending(dpy) > 0) {
    XNextEvent(dpy, &event);
    WMHandleEvent(&event);
  }
  /* WMLogError("2. _processXEvent() - %i", XPending(dpy)); */
  CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
}

void WMRunLoop_V0()
{
  XEvent event;

  WMLogError("WMRunLoop_V0: handling events while run loop is warming up.");
  while (wm_runloop == NULL) {
    WMNextEvent(dpy, &event);
    WMHandleEvent(&event);
  }
  WMLogError("WMRunLoop_V0: run loop V1 is ready.");

#ifdef HAVE_INOTIFY
  /* Track some defaults files for changes */
  w_global.inotify.fd_event_queue = -1;
  wDefaultsShouldTrackChanges(w_global.domain.window_attrs, true);
#else
  /* Setup defaults files polling */
  if (!wPreferences.flags.noupdates) {
    WMAddTimerHandler(DEFAULTS_CHECK_INTERVAL, wDefaultsCheckDomains, NULL);
  }
#endif
}

void WMRunLoop_V1()
{
  CFRunLoopRef run_loop = CFRunLoopGetCurrent();
  CFFileDescriptorRef xfd;
  CFRunLoopSourceRef xfd_source;

  WMLogError("WMRunLoop_V1: Entering WM runloop with X connection: %i", ConnectionNumber(dpy));

  // X connection file descriptor
  xfd = CFFileDescriptorCreate(kCFAllocatorDefault, ConnectionNumber(dpy), true,
                               _runLoopHandleEvent, NULL);
  CFFileDescriptorEnableCallBacks(xfd, kCFFileDescriptorReadCallBack);

  xfd_source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, xfd, 0);
  CFRunLoopAddSource(run_loop, xfd_source, kCFRunLoopDefaultMode);
  CFRelease(xfd_source);
  CFRelease(xfd);

  WMLogError("WMRunLoop_V1: Going into CFRunLoop...");

  wm_runloop = run_loop;
  CFRunLoopRun();
  CFFileDescriptorDisableCallBacks(xfd, kCFFileDescriptorReadCallBack);
  CFRunLoopRemoveSource(run_loop, xfd_source, kCFRunLoopDefaultMode);
  /* Do not call CFFileDescriptorInvalidate(xfd)!
     This FD is a connection of Workspace application to X server. */

  WMLogError("V1: CFRunLoop finished.");
}

/*
 *----------------------------------------------------------------------
 * EventLoop-
 * 	Processes X and internal events indefinitely.
 *
 * Returns:
 * 	Never returns
 *
 * Side effects:
 * 	The LastTimestamp global variable is updated.
 *      Calls inotifyGetEvents if defaults database changes.
 *----------------------------------------------------------------------
 */
noreturn void EventLoop(void)
{
  XEvent event;

  for (;;) {
    WMNextEvent(dpy, &event); /* Blocks here */
    WMHandleEvent(&event);
  }
}

/*
 *----------------------------------------------------------------------
 * ProcessPendingEvents --
 * 	Processes the events that are currently pending (at the time
 *      this function is called) in the display's queue.
 *
 * Returns:
 *      After the pending events that were present at the function call
 *      are processed.
 *
 * Side effects:
 * 	Many -- whatever handling events may involve.
 *
 *----------------------------------------------------------------------
 */
void ProcessPendingEvents(void)
{
  XEvent event;
  int count;

  XSync(dpy, False);

  /* Take a snapshot of the event count in the queue */
  count = XPending(dpy);

  while (count > 0 && XPending(dpy)) {
    XNextEvent(dpy, &event);
    /* WMNextEvent(dpy, &event); */
    WMHandleEvent(&event);
    count--;
  }
}

Bool IsDoubleClick(WScreen *scr, XEvent *event)
{
  if ((scr->last_click_time > 0) &&
      (event->xbutton.time - scr->last_click_time <= wPreferences.dblclick_time) &&
      (event->xbutton.button == scr->last_click_button) &&
      (event->xbutton.window == scr->last_click_window)) {
    scr->flags.next_click_is_not_double = 1;
    scr->last_click_time = 0;
    scr->last_click_window = event->xbutton.window;

    return True;
  }
  return False;
}

void NotifyDeadProcess(pid_t pid, unsigned char status)
{
  if (deadProcessPtr >= MAX_DEAD_PROCESSES - 1) {
    WMLogWarning("stack overflow: too many dead processes");
    return;
  }
  /* stack the process to be handled later,
   * as this is called from the signal handler */
  deadProcesses[deadProcessPtr].pid = pid;
  deadProcesses[deadProcessPtr].exit_status = status;
  deadProcessPtr++;
}

static void handleDeadProcess(void)
{
  DeathHandler *tmp;
  int i;

  for (i = 0; i < deadProcessPtr; i++) {
    wWindowDeleteSavedStatesForPID(deadProcesses[i].pid);
  }

  if (!deathHandlers) {
    deadProcessPtr = 0;
    return;
  }

  /* get the pids on the queue and call handlers */
  while (deadProcessPtr > 0) {
    deadProcessPtr--;

    for (i = CFArrayGetCount(deathHandlers) - 1; i >= 0; i--) {
      tmp = (DeathHandler *)CFArrayGetValueAtIndex(deathHandlers, i);
      if (!tmp)
        continue;

      if (tmp->pid == deadProcesses[deadProcessPtr].pid) {
        (*tmp->callback)(tmp->pid, deadProcesses[deadProcessPtr].exit_status, tmp->client_data);
        wdelete_death_handler(tmp);
      }
    }
  }
}

static void saveTimestamp(XEvent *event)
{
  /*
   * Never save CurrentTime as LastTimestamp because CurrentTime
   * it's not a real timestamp (it's the 0L constant)
   */

  switch (event->type) {
    case ButtonRelease:
    case ButtonPress:
      w_global.timestamp.last_event = event->xbutton.time;
      break;
    case KeyPress:
    case KeyRelease:
      w_global.timestamp.last_event = event->xkey.time;
      break;
    case MotionNotify:
      w_global.timestamp.last_event = event->xmotion.time;
      break;
    case PropertyNotify:
      w_global.timestamp.last_event = event->xproperty.time;
      break;
    case EnterNotify:
    case LeaveNotify:
      w_global.timestamp.last_event = event->xcrossing.time;
      break;
    case SelectionClear:
      w_global.timestamp.last_event = event->xselectionclear.time;
      break;
    case SelectionRequest:
      w_global.timestamp.last_event = event->xselectionrequest.time;
      break;
    case SelectionNotify:
      w_global.timestamp.last_event = event->xselection.time;
#ifdef USE_DOCK_XDND
      wXDNDProcessSelection(event);
#endif
      break;
  }
}

static void handleExtensions(XEvent *event)
{
#ifdef USE_XSHAPE
  if (w_global.xext.shape.supported &&
      event->type == (w_global.xext.shape.event_base + ShapeNotify)) {
    handleShapeNotify(event);
  }
#endif
#ifdef USE_XKB
  if (w_global.xext.xkb.supported && (event->type == w_global.xext.xkb.event_base)) {
    XkbEvent *e = (XkbEvent *)event;
    if (e->any.xkb_type == XkbBellNotify) {
      handleXkbBellNotify(e);
    } else if (e->any.xkb_type == XkbStateNotify) {
      handleXkbStateNotify(e);
    }
  }
#endif /* USE_XKB */
}

static void handleMapRequest(XEvent *ev)
{
  WWindow *wwin;
  WScreen *scr = NULL;
  Window window = ev->xmaprequest.window;

  scr = wDefaultScreen();

  wwin = wWindowFor(window);
  if (wwin != NULL) {
    /* WMLogInfo("MapRequest %lu", wwin->client_win); */
    if (!wwin->flags.is_gnustep && wwin->flags.shaded) {
      wUnshadeWindow(wwin);
    }
    /* deiconify and unhide*/
    if (wwin->flags.miniaturized) {
      wDeiconifyWindow(wwin);
    } else if (wwin->flags.hidden) {
      WApplication *wapp = wApplicationOf(wwin->main_window);
      /* go to the last workspace that the user worked on the app */
      if (wapp) {
        wDesktopChange(wwin->screen, wapp->last_desktop, NULL);
      }
      wUnhideApplication(wapp, False, False);
    }

    /* extra focus steps for GNUstep applications */
    if (wwin->flags.is_gnustep) {
      if (WINDOW_LEVEL(wwin) == NSMainMenuWindowLevel && wwin->flags.mapped == 0) {
        /* GNUstep application activates and maps main menu.
           Main menu window is managed but unmapped.*/
        WApplication *wapp = wApplicationOf(wwin->main_window);

        wWindowMap(wwin);
        /* It's minimal app (menu only) or menu should be focused on workspace
           different from last focused window's. */
        if (!wapp->last_focused || wapp->last_focused->flags.mapped == 0) {
          wSetFocusTo(scr, wwin);
        }
      }
    }
    return;
  }

  wwin = wManageWindow(scr, window);

  /*
   * This is to let the Dock know that the application it launched
   * has already been mapped (eg: it has finished launching).
   * It is not necessary for normally docked apps, but is needed for
   * apps that were forcedly docked (like with dockit).
   */
  if (scr->last_dock) {
    if (wwin && wwin->main_window != None && wwin->main_window != window)
      wDockTrackWindowLaunch(scr->last_dock, wwin->main_window);
    else
      wDockTrackWindowLaunch(scr->last_dock, window);
  }

  if (wwin) {
    wClientSetState(wwin, NormalState, None);
    if (wwin->flags.maximized) {
      wMaximizeWindow(wwin, wwin->flags.maximized);
    }
    if (wwin->flags.shaded) {
      wwin->flags.shaded = 0;
      wwin->flags.skip_next_animation = 1;
      wShadeWindow(wwin);
    }
    if (wwin->flags.miniaturized) {
      wwin->flags.miniaturized = 0;
      wwin->flags.skip_next_animation = 1;
      wIconifyWindow(wwin);
    }
    if (wwin->flags.fullscreen) {
      wwin->flags.fullscreen = 0;
      wFullscreenWindow(wwin);
    }
    if (wwin->flags.hidden) {
      WApplication *wapp = wApplicationOf(wwin->main_window);

      wwin->flags.hidden = 0;
      wwin->flags.skip_next_animation = 1;
      if (wapp) {
        wApplicationHide(wapp);
      }
    }
  }
}

static void handleDestroyNotify(XEvent *event)
{
  WWindow *wwin;
  WApplication *app;
  Window window = event->xdestroywindow.window;
  WScreen *scr = wDefaultScreen();
  CFIndex widx;

  wwin = wWindowFor(window);
  if (wwin) {
    /* WMLogInfo("DestroyNotify will unmanage window:%lu", window); */
    wUnmanageWindow(wwin, False, True);
  }

  if (scr != NULL) {
    WFakeGroupLeader *fPtr;
    do {
      widx = kCFNotFound;
      for (int i = 0; i < CFArrayGetCount(scr->fakeGroupLeaders); i++) {
        fPtr = (WFakeGroupLeader *)CFArrayGetValueAtIndex(scr->fakeGroupLeaders, i);
        if (fPtr->origLeader == window) {
          widx = i;
          break;
        }
      }
      if (widx != kCFNotFound) {
        if (fPtr->retainCount > 0) {
          fPtr->retainCount--;
          if (fPtr->retainCount == 0 && fPtr->leader != None) {
            XDestroyWindow(dpy, fPtr->leader);
            fPtr->leader = None;
            XFlush(dpy);
          }
        }
        fPtr->origLeader = None;
      }
    } while (widx != kCFNotFound);
  }

  app = wApplicationOf(window);
  if (app) {
    /* If main window was destroyed - unmanage all windows of app
       and remove app's information structure (WApplication). */
    if (window == app->main_window) {
      int window_count = CFArrayGetCount(app->windows);

      for (int i = 0; i < window_count; i++) {
        wwin = (WWindow *)CFArrayGetValueAtIndex(app->windows, 0);
        if (wwin->client_win != app->main_window) {
          wUnmanageWindow(wwin, False, True);
        }
      }
    }
    wApplicationDestroy(app);
  }
}

static void handleExpose(XEvent *event)
{
  WObjDescriptor *desc;
  XEvent ev;

  while (XCheckTypedWindowEvent(dpy, event->xexpose.window, Expose, &ev))
    ;

  if (XFindContext(dpy, event->xexpose.window, w_global.context.client_win, (XPointer *)&desc) ==
      XCNOENT) {
    return;
  }

  if (desc->handle_expose) {
    (*desc->handle_expose)(desc, event);
  }
}

static void executeWheelAction(WScreen *scr, XEvent *event, int action)
{
  WWindow *wwin;
  Bool next_direction;

  if (event->xbutton.button == Button5 || event->xbutton.button == Button6)
    next_direction = False;
  else
    next_direction = True;

  switch (action) {
    case WA_SWITCH_WORKSPACES:
      if (next_direction)
        wDesktopRelativeChange(scr, 1);
      else
        wDesktopRelativeChange(scr, -1);
      break;

    case WA_SWITCH_WINDOWS:
      wwin = scr->focused_window;
      if (next_direction)
        wWindowFocusNext(wwin, True);
      else
        wWindowFocusPrev(wwin, True);
      break;
  }
}

static void executeButtonAction(WScreen *scr, XEvent *event, int action)
{
  WWindow *wwin;

  switch (action) {
    case WA_SELECT_WINDOWS:
      wUnselectWindows(scr);
      wSelectWindows(scr, event);
      break;
    case WA_OPEN_WINLISTMENU:
      OpenSwitchMenu(scr, event->xbutton.x_root, event->xbutton.y_root, False);
      if (scr->switch_menu) {
        if (scr->switch_menu->brother->flags.mapped)
          event->xbutton.window = scr->switch_menu->brother->frame->core->window;
        else
          event->xbutton.window = scr->switch_menu->frame->core->window;
      }
      break;
    case WA_MOVE_PREVWORKSPACE:
      wDesktopRelativeChange(scr, -1);
      break;
    case WA_MOVE_NEXTWORKSPACE:
      wDesktopRelativeChange(scr, 1);
      break;
    case WA_MOVE_PREVWINDOW:
      wwin = scr->focused_window;
      wWindowFocusPrev(wwin, True);
      break;
    case WA_MOVE_NEXTWINDOW:
      wwin = scr->focused_window;
      wWindowFocusNext(wwin, True);
      break;
  }
}

/* bindable */
static void handleButtonPress(XEvent *event)
{
  WObjDescriptor *desc = NULL;
  WScreen *scr = wDefaultScreen();
  WApplication *wapp = NULL;

  // reset current focused window button because ButtonPress may change focus
  WWindow *wwin = scr->focused_window;
  if (wwin && wwin->client_win != scr->no_focus_win && wwin->frame && wwin->frame->left_button &&
      event->xbutton.window != wwin->frame->left_button->window && wwin->frame->right_button &&
      event->xbutton.window != wwin->frame->right_button->window) {
    scr->flags.modifier_pressed = 0;
    wWindowUpdateButtonImages(wwin);
  }

#ifdef BALLOON_TEXT
  wBalloonHide(scr);
#endif

  if (!wPreferences.disable_root_mouse && event->xbutton.window == scr->root_win) {
    if (event->xbutton.button == Button1 && wPreferences.mouse_button1 != WA_NONE) {
      if (scr->focused_window && scr->focused_window->flags.is_gnustep) {
        XSendEvent(dpy, scr->focused_window->client_win, False, ButtonPressMask, event);
      } else {
        XSendEvent(dpy, scr->dock->icon_array[0]->icon->icon_win, False, ButtonPressMask, event);
      }
    } else if (event->xbutton.button == Button2 && wPreferences.mouse_button2 != WA_NONE) {
      executeButtonAction(scr, event, wPreferences.mouse_button2);
    } else if (event->xbutton.button == Button3 && wPreferences.mouse_button3 != WA_NONE) {
      if (scr->focused_window) {
        wapp = wApplicationForWindow(scr->focused_window);
      }
      if (scr->focused_window && scr->focused_window->flags.is_gnustep) {
        XSendEvent(dpy, scr->focused_window->client_win, False, ButtonPressMask, event);
      } else if (wapp) {
        desc = &wapp->app_icon->icon->core->descriptor;
      } else {
        XSendEvent(dpy, scr->dock->icon_array[0]->icon->icon_win, False, ButtonPressMask, event);
      }
    } else if (event->xbutton.button == Button4 && wPreferences.mouse_wheel_scroll != WA_NONE) {
      executeWheelAction(scr, event, wPreferences.mouse_wheel_scroll);
    } else if (event->xbutton.button == Button5 && wPreferences.mouse_wheel_scroll != WA_NONE) {
      executeWheelAction(scr, event, wPreferences.mouse_wheel_scroll);
    } else if (event->xbutton.button == Button6 && wPreferences.mouse_wheel_tilt != WA_NONE) {
      executeWheelAction(scr, event, wPreferences.mouse_wheel_tilt);
    } else if (event->xbutton.button == Button7 && wPreferences.mouse_wheel_tilt != WA_NONE) {
      executeWheelAction(scr, event, wPreferences.mouse_wheel_tilt);
    } else if (event->xbutton.button == Button8 && wPreferences.mouse_button8 != WA_NONE) {
      executeButtonAction(scr, event, wPreferences.mouse_button8);
    } else if (event->xbutton.button == Button9 && wPreferences.mouse_button9 != WA_NONE) {
      executeButtonAction(scr, event, wPreferences.mouse_button9);
    }
  }

  /* desc = NULL; */
  if (desc == NULL) {
    if (XFindContext(dpy, event->xbutton.subwindow, w_global.context.client_win,
                     (XPointer *)&desc) == XCNOENT) {
      if (XFindContext(dpy, event->xbutton.window, w_global.context.client_win,
                       (XPointer *)&desc) == XCNOENT) {
        return;
      }
    }
  }

  if (desc->parent_type == WCLASS_WINDOW) {
    XSync(dpy, 0);
    if (event->xbutton.state & (ALT_MOD_MASK | ControlMask)) {
      XAllowEvents(dpy, AsyncPointer, CurrentTime);
    } else if (wPreferences.ignore_focus_click) {
      XAllowEvents(dpy, AsyncPointer, CurrentTime);
    } else {
      XAllowEvents(dpy, ReplayPointer, CurrentTime);
    }
    XSync(dpy, 0);
  } else if (desc->parent_type == WCLASS_APPICON || desc->parent_type == WCLASS_MINIWINDOW ||
             desc->parent_type == WCLASS_DOCK_ICON) {
    if (event->xbutton.state & wPreferences.cmd_modifier_mask) {
      WAppIcon *appicon = wAppIconFor(event->xbutton.window);
      WAppIcon *appicon0 = scr->dock->icon_array[0];
      if ((desc->parent_type == WCLASS_DOCK_ICON) &&
          (appicon->icon->icon_win == appicon0->icon->icon_win)) {
        if (wDockLevel(scr->dock) == NSDockWindowLevel) {
          wDockSetLevel(scr->dock, NSNormalWindowLevel);
        } else {
          wDockSetLevel(scr->dock, NSDockWindowLevel);
        }
        XUngrabPointer(dpy, CurrentTime);
        return;
      } else {
        XSync(dpy, 0);
        XAllowEvents(dpy, AsyncPointer, CurrentTime);
        XSync(dpy, 0);
      }
    }
  }

  if (desc->handle_mousedown != NULL) {
    (*desc->handle_mousedown)(desc, event);
  }

  /* save double-click information */
  if (scr->flags.next_click_is_not_double) {
    scr->flags.next_click_is_not_double = 0;
  } else {
    scr->last_click_time = event->xbutton.time;
    scr->last_click_button = event->xbutton.button;
    scr->last_click_window = event->xbutton.window;
  }
}

static void handleButtonRelease(XEvent *event)
{
  WScreen *scr = wDefaultScreen();

  if (!wPreferences.disable_root_mouse && event->xbutton.window == scr->root_win &&
      event->xbutton.button == Button3) {
    if (scr->focused_window && scr->focused_window->flags.is_gnustep) {
      XSendEvent(dpy, scr->focused_window->client_win, True, ButtonReleaseMask, event);
    } else {
      XSendEvent(dpy, scr->dock->icon_array[0]->icon->icon_win, False, ButtonReleaseMask, event);
    }
  }
}

static void handleMapNotify(XEvent *event)
{
  WWindow *wwin;

  wwin = wWindowFor(event->xmap.event);
  if (wwin && wwin->client_win == event->xmap.event) {
    /* WMLogInfo(" MapNotify %lu", wwin->client_win); */
    if (wwin->flags.miniaturized) {
      wDeiconifyWindow(wwin);
    } else {
      XGrabServer(dpy);
      wWindowMap(wwin);
      wClientSetState(wwin, NormalState, None);
      XUngrabServer(dpy);
    }
  }
}

static void handleUnmapNotify(XEvent *event)
{
  WWindow *wwin;
  XEvent ev;
  Bool withdraw = False;

  /* WMLogInfo("handleUnmapNotify for window %lu.", event->xunmap.window); */

  /* only process windows with StructureNotify selected (ignore SubstructureNotify) */
  wwin = wWindowFor(event->xunmap.window);
  if (!wwin)
    return;

  /* whether the event is a Withdrawal request */
  if (event->xunmap.event == wwin->screen->root_win && event->xunmap.send_event)
    withdraw = True;

  if (wwin->client_win != event->xunmap.event && !withdraw)
    return;

  if (!wwin->flags.mapped && !withdraw && wwin->frame->desktop == wwin->screen->current_desktop &&
      !wwin->flags.miniaturized && !wwin->flags.hidden)
    return;

  XGrabServer(dpy);
  XUnmapWindow(dpy, wwin->frame->core->window);
  wwin->flags.mapped = 0;
  XSync(dpy, 0);
  /* check if the window was destroyed */
  if (XCheckTypedWindowEvent(dpy, wwin->client_win, DestroyNotify, &ev)) {
    XUngrabServer(dpy);
    DispatchEvent(&ev);
  } else {
    Bool reparented = False;

    if (XCheckTypedWindowEvent(dpy, wwin->client_win, ReparentNotify, &ev))
      reparented = True;

    /* withdraw window */
    wwin->flags.mapped = 0;
    if (!reparented)
      wClientSetState(wwin, WithdrawnState, None);

    if (WINDOW_LEVEL(wwin) != NSMainMenuWindowLevel) {
      /* WMLogInfo("UnmapNotify will unmanage window:%lu is_gnustep=%i", */
      /*         event->xunmap.window, wwin->flags.is_gnustep); */
      /* if the window was reparented, do not reparent it back to the
       * root window */
      wUnmanageWindow(wwin, !reparented, False);
    }
    XUngrabServer(dpy);
  }
}

static void handleConfigureRequest(XEvent *event)
{
  WWindow *wwin;

  wwin = wWindowFor(event->xconfigurerequest.window);
  if (wwin == NULL) {
    /*
     * Configure request for unmapped window
     */
    wClientConfigure(NULL, &(event->xconfigurerequest));
  } else {
    wClientConfigure(wwin, &(event->xconfigurerequest));
  }
}

static void handlePropertyNotify(XEvent *event)
{
  WWindow *wwin;
  WApplication *wapp;
  Window jr;
  int ji;
  unsigned int ju;

  wwin = wWindowFor(event->xproperty.window);
  if (wwin) {
    if (!XGetGeometry(dpy, wwin->client_win, &jr, &ji, &ji, &ju, &ju, &ju, &ju)) {
      return;
    }
    wClientCheckProperty(wwin, &event->xproperty);
  }
  wapp = wApplicationOf(event->xproperty.window);
  if (wapp) {
    wClientCheckProperty(wapp->main_wwin, &event->xproperty);
  }
}

static void handleClientMessage(XEvent *event)
{
  WWindow *wwin;
  WObjDescriptor *desc;

  /* handle transition from Normal to Iconic state */
  if (event->xclient.message_type == w_global.atom.wm.change_state && event->xclient.format == 32 &&
      event->xclient.data.l[0] == IconicState) {
    wwin = wWindowFor(event->xclient.window);
    if (!wwin)
      return;
    if (!wwin->flags.miniaturized)
      wIconifyWindow(wwin);
  } else if (event->xclient.message_type == w_global.atom.wm.colormap_notify &&
             event->xclient.format == 32) {
    WScreen *scr = wDefaultScreen();

    if (!scr)
      return;

    if (event->xclient.data.l[1] == 1) { /* starting */
      wColormapAllowClientInstallation(scr, True);
    } else { /* stopping */
      wColormapAllowClientInstallation(scr, False);
    }
  } else if (event->xclient.message_type == w_global.atom.wmaker.command) {
    char *command;
    size_t len;

    len = sizeof(event->xclient.data.b) + 1;
    command = wmalloc(len);
    strncpy(command, event->xclient.data.b, sizeof(event->xclient.data.b));

    if (strncmp(command, "Reconfigure", sizeof("Reconfigure")) == 0) {
      WMLogWarning(_("Got Reconfigure command"));
      wDefaultsUpdateDomainsIfNeeded(NULL);
    } else {
      WMLogWarning(_("Got unknown command %s"), command);
    }

    wfree(command);

  } else if (event->xclient.message_type == w_global.atom.wmaker.wm_function) {
    WApplication *wapp;
    int done = 0;
    wapp = wApplicationOf(event->xclient.window);
    WMLogInfo("Received client message: %li for: %s", event->xclient.data.l[0],
              wapp ? wapp->main_wwin->wm_instance : "Unknown");
    if (wapp) {
      switch (event->xclient.data.l[0]) {
        case WMFHideOtherApplications:
          wApplicationHideOthers(wapp->main_wwin);
          done = 1;
          break;

        case WMFHideApplication:
          WMLogInfo("Received WMFHideApplication client message");
          wApplicationHide(wapp);
          done = 1;
          break;
      }
    }
    if (!done) {
      wwin = wWindowFor(event->xclient.window);
      if (wwin) {
        switch (event->xclient.data.l[0]) {
          case WMFHideOtherApplications:
            wApplicationHideOthers(wwin);
            break;

          case WMFHideApplication:
            wApplicationHide(wApplicationOf(wwin->main_window));
            break;
        }
      }
    }
  } else if (event->xclient.message_type == w_global.atom.gnustep.wm_attr) {
    wwin = wWindowFor(event->xclient.window);
    if (!wwin)
      return;
    switch (event->xclient.data.l[0]) {
      case GSWindowLevelAttr: {
        int level = (int)event->xclient.data.l[1];

        if (WINDOW_LEVEL(wwin) != level) {
          ChangeStackingLevel(wwin->frame->core, level);
        }
      } break;
    }
  } else if (event->xclient.message_type == w_global.atom.gnustep.titlebar_state) {
    wwin = wWindowFor(event->xclient.window);
    if (!wwin)
      return;
    switch (event->xclient.data.l[0]) {
      case WMTitleBarNormal:
        wFrameWindowChangeState(wwin->frame, WS_UNFOCUSED);
        break;
      case WMTitleBarMain:
        wFrameWindowChangeState(wwin->frame, WS_PFOCUSED);
        break;
      case WMTitleBarKey:
        wFrameWindowChangeState(wwin->frame, WS_FOCUSED);
        break;
    }
  } else if (event->xclient.message_type == w_global.atom.wm.ignore_focus_events) {
    WScreen *scr = wDefaultScreen();
    if (!scr)
      return;
    scr->flags.ignore_focus_events = event->xclient.data.l[0] ? 1 : 0;
  } else if (wNETWMProcessClientMessage(&event->xclient)) {
    /* do nothing */
#ifdef USE_DOCK_XDND
  } else if (wXDNDProcessClientMessage(&event->xclient)) {
    /* do nothing */
#endif /* USE_DOCK_XDND */
  } else {
    /*
     * Non-standard thing, but needed by OffiX DND.
     * For when the icon frame gets a ClientMessage
     * that should have gone to the icon_window.
     */
    if (XFindContext(dpy, event->xbutton.window, w_global.context.client_win, (XPointer *)&desc) !=
        XCNOENT) {
      struct WIcon *icon = NULL;

      if (desc->parent_type == WCLASS_MINIWINDOW) {
        icon = (WIcon *)desc->parent;
      } else if (desc->parent_type == WCLASS_DOCK_ICON || desc->parent_type == WCLASS_APPICON) {
        icon = ((WAppIcon *)desc->parent)->icon;
      }
      if (icon && (wwin = icon->owner)) {
        if (wwin->client_win != event->xclient.window) {
          event->xclient.window = wwin->client_win;
          XSendEvent(dpy, wwin->client_win, False, NoEventMask, event);
        }
      }
    }
  }
}

static void handleEnterNotify(XEvent *event)
{
  WWindow *wwin;
  WObjDescriptor *desc = NULL;
  XEvent ev;
  WScreen *scr = wDefaultScreen();

  if (XCheckTypedWindowEvent(dpy, event->xcrossing.window, LeaveNotify, &ev)) {
    /* already left the window... */
    saveTimestamp(&ev);
    if (ev.xcrossing.mode == event->xcrossing.mode &&
        ev.xcrossing.detail == event->xcrossing.detail) {
      return;
    }
  }

  if (XFindContext(dpy, event->xcrossing.window, w_global.context.client_win, (XPointer *)&desc) !=
      XCNOENT) {
    if (desc->handle_enternotify)
      (*desc->handle_enternotify)(desc, event);
  }

  /* enter to window */
  wwin = wWindowFor(event->xcrossing.window);
  if (!wwin) {
    if (wPreferences.colormap_mode == WCM_POINTER) {
      wColormapInstallForWindow(scr, NULL);
    }
    if (scr->autoRaiseTimer && event->xcrossing.root == event->xcrossing.window) {
      WMDeleteTimerHandler(scr->autoRaiseTimer);
      scr->autoRaiseTimer = NULL;
    }
  } else {
    /* Install colormap for window, if the colormap installation mode
     * is colormap_follows_mouse */
    if (wPreferences.colormap_mode == WCM_POINTER) {
      if (wwin->client_win == event->xcrossing.window)
        wColormapInstallForWindow(scr, wwin);
      else
        wColormapInstallForWindow(scr, NULL);
    }
  }

#ifdef BALLOON_TEXT
  wBalloonEnteredObject(scr, desc);
#endif

  if (wPreferences.scrollable_menus) {
    WMenu *menu = wMenuUnderPointer(scr);
    if (menu != NULL && menu->timer == NULL) {
      wMenuSlideIfNeeded(menu);
    }
  }
}

static void handleLeaveNotify(XEvent *event)
{
  WObjDescriptor *desc = NULL;

  if (XFindContext(dpy, event->xcrossing.window, w_global.context.client_win, (XPointer *)&desc) !=
      XCNOENT) {
    if (desc->handle_leavenotify)
      (*desc->handle_leavenotify)(desc, event);
  }
}

#ifdef USE_XSHAPE
static void handleShapeNotify(XEvent *event)
{
  XShapeEvent *shev = (XShapeEvent *)event;
  WWindow *wwin;
  union {
    XEvent xevent;
    XShapeEvent xshape;
  } ev;

  while (XCheckTypedWindowEvent(dpy, shev->window, event->type, &ev.xevent)) {
    if (ev.xshape.kind == ShapeBounding) {
      if (ev.xshape.shaped == shev->shaped) {
        *shev = ev.xshape;
      } else {
        XPutBackEvent(dpy, &ev.xevent);
        break;
      }
    }
  }

  wwin = wWindowFor(shev->window);
  if (!wwin || shev->kind != ShapeBounding)
    return;

  if (!shev->shaped && wwin->flags.shaped) {
    wwin->flags.shaped = 0;
    wWindowClearShape(wwin);

  } else if (shev->shaped) {
    wwin->flags.shaped = 1;
    wWindowSetShape(wwin);
  }
}
#endif /* USE_XSHAPE */

#ifdef USE_XKB
static void handleXkbBellNotify(XkbEvent *event)
{
  WWindow *wwin;
  WScreen *scr;

  scr = wDefaultScreen();
  wwin = scr->focused_window;
  if (wwin && wwin->flags.focused) {
    WSRingBell(wwin);
  }
}
static void handleXkbStateNotify(XkbEvent *event)
{
  WWindow *wwin;
  WScreen *scr;
  XkbStateRec staterec;
  CFMutableDictionaryRef info;
  CFNumberRef group;

  scr = wDefaultScreen();
  wwin = scr->focused_window;
  if (wwin && wwin->flags.focused) {
    XkbGetState(dpy, XkbUseCoreKbd, &staterec);

    info = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks,
                                     &kCFTypeDictionaryValueCallBacks);
    group = CFNumberCreate(kCFAllocatorDefault, kCFNumberCharType, &staterec.group);
    CFDictionaryAddValue(info, CFSTR("XkbGroup"), group);
    CFRelease(group);
    CFNotificationCenterPostNotification(scr->notificationCenter,
                                         WMDidChangeKeyboardLayoutNotification, wwin, info, TRUE);
    CFRelease(info);
  }
}
#endif /* USE_XKB */

static void handleColormapNotify(XEvent *event)
{
  WWindow *wwin;
  WScreen *scr;
  Bool reinstall = False;

  wwin = wWindowFor(event->xcolormap.window);
  if (!wwin)
    return;

  scr = wwin->screen;

  do {
    if (wwin) {
      if (event->xcolormap.new) {
        XWindowAttributes attr;

        XGetWindowAttributes(dpy, wwin->client_win, &attr);

        if (wwin == scr->cmap_window && wwin->cmap_window_no == 0)
          scr->current_colormap = attr.colormap;

        reinstall = True;
      } else if (event->xcolormap.state == ColormapUninstalled &&
                 scr->current_colormap == event->xcolormap.colormap) {
        /* some bastard app (like XV) removed our colormap */
        /*
         * can't enforce or things like xscreensaver wont work
         * reinstall = True;
         */
      } else if (event->xcolormap.state == ColormapInstalled &&
                 scr->current_colormap == event->xcolormap.colormap) {
        /* someone has put our colormap back */
        reinstall = False;
      }
    }
  } while (XCheckTypedEvent(dpy, ColormapNotify, event) &&
           ((wwin = wWindowFor(event->xcolormap.window)) || 1));

  if (reinstall && scr->current_colormap != None) {
    if (!scr->flags.colormap_stuff_blocked)
      XInstallColormap(dpy, scr->current_colormap);
  }
}

static void handleFocusIn(XEvent *event)
{
  WWindow *wwin;

  /*
   * For applications that like stealing the focus.
   */
  while (XCheckTypedEvent(dpy, FocusIn, event))
    ;
  saveTimestamp(event);
  if (event->xfocus.mode == NotifyUngrab || event->xfocus.mode == NotifyGrab ||
      event->xfocus.detail > NotifyNonlinearVirtual) {
    return;
  }

  wwin = wWindowFor(event->xfocus.window);
  if (wwin && !wwin->flags.focused) {
    if (wwin->flags.mapped) {
      wSetFocusTo(wwin->screen, wwin);
      wRaiseFrame(wwin->frame->core);
    } else {
      wSetFocusTo(wwin->screen, NULL);
    }
  } else if (!wwin) {
    WScreen *scr = wDefaultScreen();
    if (scr)
      wSetFocusTo(scr, NULL);
  }
}

// static WWindow *windowUnderPointer(WScreen *scr)
// {
//   unsigned int mask;
//   int foo;
//   Window bar, win;

//   if (XQueryPointer(dpy, scr->root_win, &bar, &win, &foo, &foo, &foo, &foo, &mask))
//     return wWindowFor(win);
//   return NULL;
// }

// static int CheckFullScreenWindowFocused(WScreen *scr)
// {
//   if (scr->focused_window && scr->focused_window->flags.fullscreen)
//     return 1;
//   else
//     return 0;
// }

static void handleKeyPress(XEvent *event)
{
  WScreen *scr = wDefaultScreen();
  WWindow *wwin = scr->focused_window;
  short i, widx;
  int modifiers;
  int command = -1;

  /* ignore CapsLock */
  modifiers = event->xkey.state & w_global.shortcut.modifiers_mask;

  WMLogInfo("handleKeyPress: %i state: %i modifiers: %i", event->xkey.keycode, event->xkey.state,
            modifiers);

  /* Handle Alternate button press to change miniaturize button image at titlebar */
  if (((event->xkey.keycode == XKeysymToKeycode(dpy, XK_Super_L)) ||
       (event->xkey.keycode == XKeysymToKeycode(dpy, XK_Super_R))) &&
      modifiers == 0) {
    if (wwin &&
        wwin->client_win /* != scr->no_focus_win && event->xkey.window != event->xkey.root */) {
      scr->flags.modifier_pressed = 1;
      wWindowUpdateButtonImages(wwin);
    }
  } else if (event->xkey.window != event->xkey.root && event->xkey.window != scr->no_focus_win) {
    scr->flags.modifier_pressed = 0;
    wWindowUpdateButtonImages(wwin);
  }

  /* Pass key press to application menu of non-GNUstep applications.
     If application menu has such shortcut function returns `True` */
  if (wApplicationMenuHandleKeyPress(wwin, event) == True) {
    return;
  }

  for (i = 0; i < WKBD_LAST; i++) {
    if (wKeyBindings[i].keycode == 0) {
      continue;
    }
    if ((event->xkey.keycode == wKeyBindings[i].keycode) &&
        (wKeyBindings[i].modifier == modifiers)) {
      command = i;
      break;
    }
  }

  if (command < 0) {
    static int dontLoop = 0;

    if (dontLoop > 10) {
      WMLogWarning("problem with key event processing code");
      return;
    }
    dontLoop++;
    /* if the focused window is an internal window, try redispatching
     * the event to the managed window, as it can be a WINGs window */
    if (wwin && wwin->flags.internal_window && wwin->client_leader != None) {
      /* client_leader contains the WINGs toplevel */
      event->xany.window = wwin->client_leader;
      WMHandleEvent(event);
    }
    dontLoop--;

    // Shortuct which does not overlap with WM shortcuts was pressed -
    // send it to GNUstep application. For example, Alternate-x
    // pressed over Terminal window which runs Emacs should result in
    // appearing 'M-x' prompt in Emacs.
    if (wwin && wwin->flags.is_gnustep) {
      XSendEvent(dpy, wwin->client_win, True, KeyPress, event);
    }
    return;
  }

#define ISMAPPED(w) ((w) && !(w)->flags.miniaturized && ((w)->flags.mapped || (w)->flags.shaded))
#define ISFOCUSED(w) ((w) && (w)->flags.focused)

  switch (command) {
      /* case WKBD_RAISE: */
      /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin)) { */
      /*     CloseWindowMenu(scr); */
      /*     wRaiseFrame(wwin->frame->core); */
      /*   } */
      /*   break; */
      /* case WKBD_LOWER: */
      /*   if (ISMAPPED(wwin) && ISFOCUSED(wwin)) { */
      /*     CloseWindowMenu(scr); */
      /*     wLowerFrame(wwin->frame->core); */
      /*   } */
      /*   break; */

      /* Dock and Icon Yard */
      /* case WKBD_DOCKHIDESHOW: */
      /*   if (!wwin || strcmp(wwin->wm_instance, "Workspace") != 0) { */
      /*     if (scr->dock->mapped) { */
      /*       wDockHideIcons(scr->dock); */
      /*     } else { */
      /*       wDockShowIcons(scr->dock); */
      /*     } */
      /*     } else { */
      /*       XSendEvent(dpy, wwin->client_win, True, KeyPressMask, event); */
      /*     } */
      /*   } */
      /*   break; */
      /* case WKBD_YARDHIDESHOW: */
      /*   { */
      /*     if (!wwin || strcmp(wwin->wm_instance, "Workspace") != 0) { */
      /*       if (scr->flags.icon_yard_mapped) { */
      /*         wIconYardHideIcons(scr); */
      /*       } */
      /*       else { */
      /*         wIconYardShowIcons(scr); */
      /*       } */
      /*     } else { */
      /*       XSendEvent(dpy, wwin->client_win, True, KeyPressMask, event); */
      /*     } */
      /*   } */
      /*   break; */

      /* Desktops navigation */
    case WKBD_NEXT_APP:
      wSwitchPanelStart(wwin, event, True);
      break;
    case WKBD_PREV_APP:
      wSwitchPanelStart(wwin, event, False);
      break;
    case WKBD_NEXT_WIN:
      wApplicationSwitchWindow(wwin, True);
      break;
    case WKBD_PREV_WIN:
      wApplicationSwitchWindow(wwin, False);
      break;

    case WKBD_NEXT_DESKTOP:
      wDesktopRelativeChange(scr, 1);
      break;
    case WKBD_PREV_DESKTOP:
      wDesktopRelativeChange(scr, -1);
      break;
    case WKBD_LAST_DESKTOP:
      wDesktopChange(scr, scr->last_desktop, NULL);
      break;
    case WKBD_DESKTOP_1 ... WKBD_DESKTOP_10: {
      widx = command - WKBD_DESKTOP_1;
      i = (scr->current_desktop / 10) * 10 + widx;
      if (wPreferences.ws_advance || i < scr->desktop_count)
        wDesktopChange(scr, i, NULL);
    } break;

    case WKBD_RELAUNCH:
      if (ISMAPPED(wwin) && ISFOCUSED(wwin)) {
        (void)wRelaunchWindow(wwin);
      }
      break;
  }
}

// NEXTSPACE
static void handleKeyRelease(XEvent *event)
{
  WScreen *scr = wDefaultScreen();
  WWindow *wwin = scr->focused_window;

  if (event->xkey.window == event->xkey.root || event->xkey.window == scr->no_focus_win) {
    return;
  }
  /* WMLogInfo("handleKeyRelease: %i state: %i mask: %i", */
  /*         event->xkey.keycode, event->xkey.state, MOD_MASK); */
  if ((event->xkey.keycode == XKeysymToKeycode(dpy, XK_Super_L)) ||
      (event->xkey.keycode == XKeysymToKeycode(dpy, XK_Super_R))) {
    if (wwin) {
      scr->flags.modifier_pressed = 0;
      wWindowUpdateButtonImages(wwin);
      if (wwin->flags.is_gnustep) {
        XSendEvent(dpy, scr->focused_window->client_win, True, KeyRelease, event);
      }
    }
  }
}

static void handleMotionNotify(XEvent *event)
{
  WWindow *wwin = wWindowFor(event->xmotion.window);

  if (event->xmotion.state != 0 && wwin != NULL) {
    if (event->xmotion.state & Button1Mask &&
        XGrabPointer(dpy, event->xmotion.window, False,
                     ButtonMotionMask | ButtonReleaseMask | ButtonPressMask, GrabModeAsync,
                     GrabModeAsync, None, None, CurrentTime) == GrabSuccess) {
      // wMouseMoveWindow checks for button on ButtonRelease event inside it's loop
      event->xbutton.button = Button1;
      if (event->xmotion.window == wwin->frame->titlebar->window ||
          event->xmotion.state & ALT_MOD_MASK) {
        /* move the window */
        wMouseMoveWindow(wwin, event);
      } else if (IS_RESIZABLE(wwin) && event->xmotion.window == wwin->frame->resizebar->window) {
        wMouseResizeWindow(wwin, event);
      }
      XUngrabPointer(dpy, CurrentTime);
    }
  }
}

static void handleVisibilityNotify(XEvent *event)
{
  WWindow *wwin;

  wwin = wWindowFor(event->xvisibility.window);
  if (!wwin)
    return;
  wwin->flags.obscured = (event->xvisibility.state == VisibilityFullyObscured);
}

static void handle_selection_request(XSelectionRequestEvent *event)
{
#ifdef USE_ICCCM_WMREPLACE
  static Atom atom_version = None;
  WScreen *scr;
  XSelectionEvent notify;

  /*
   * This event must be sent to the slection requester to not block him
   *
   * We create it with the answer 'there is no selection' by default
   */
  notify.type = SelectionNotify;
  notify.display = dpy;
  notify.requestor = event->requestor;
  notify.selection = event->selection;
  notify.target = event->target;
  notify.property = None; /* This says that there is no selection */
  notify.time = event->time;

  scr = wScreenForWindow(event->owner);
  if (!scr)
    goto not_our_selection;

  if (event->owner != scr->info_window)
    goto not_our_selection;

  if (event->selection != scr->sn_atom)
    goto not_our_selection;

  if (atom_version == None)
    atom_version = XInternAtom(dpy, "VERSION", False);

  if (event->target == atom_version) {
    static const long icccm_version[] = {2, 0};

    /*
     * This protocol is defined in ICCCM 2.0:
     * http://www.x.org/releases/X11R7.7/doc/xorg-docs/icccm/icccm.html
     *  "Communication with the Window Manager by Means of Selections"
     */

    /*
     * Setting the property means the content of the selection is available
     * According to the ICCCM spec, we need to support being asked for a property
     * set to 'None' for compatibility with old clients
     */
    notify.property = (event->property == None) ? (event->target) : (event->property);

    XChangeProperty(dpy, event->requestor, notify.property, XA_INTEGER, 32, PropModeReplace,
                    (unsigned char *)icccm_version, wlengthof(icccm_version));
  }

not_our_selection:
  if (notify.property == None)
    WMLogWarning("received SelectionRequest(%s) for target=\"%s\" from requestor 0x%lX but we have "
                 "no answer",
                 XGetAtomName(dpy, event->selection), XGetAtomName(dpy, event->target),
                 (long)event->requestor);

  /* Send the answer to the requestor */
  XSendEvent(dpy, event->requestor, False, 0L, (XEvent *)&notify);

#else
  /*
   * If the support for ICCCM window manager replacement was not enabled, we should not receive
   * this kind of event, so we just ignore it (Conceptually, we should reply with 'SelectionNotify'
   * event with property set to 'None' to tell that we don't have this selection, but that is a bit
   * costly for an event that shall never happen).
   */
  (void)event;
#endif
}

static void handle_selection_clear(XSelectionClearEvent *event)
{
#ifdef USE_ICCCM_WMREPLACE
  WScreen *scr = wScreenForWindow(event->window);

  if (!scr)
    return;

  if (event->selection != scr->sn_atom)
    return;

  WMLogInfo(_("another window manager is replacing us!"));
  Shutdown(WSExitMode);
#else
  /*
   * If the support for ICCCM window manager replacement was not enabled, we should not receive
   * this kind of event, so we simply do nothing.
   */
  (void)event;
#endif
}
