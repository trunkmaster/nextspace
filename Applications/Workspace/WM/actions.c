/* misc. window commands (miniaturize, hide etc.)
 *
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1998-2003 Dan Pascu
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <math.h>
#include <time.h>

#include <core/util.h>
#include <core/log_utils.h>
#include <core/wevent.h>
#include <core/drawing.h>

#include "GNUstep.h"
#include "framewin.h"
#include "window.h"
#include "client.h"
#include "icon.h"
#include "colormap.h"
#include "application.h"
#include "stacking.h"
#include "appicon.h"
#include "dock.h"
#include "desktop.h"
#include "xrandr.h"
#include "placement.h"
#include "misc.h"
#include "event.h"
#include "animations.h"
#include "iconyard.h"

#include "actions.h"

static void find_Maximus_geometry(WWindow *wwin, WArea usableArea, int *new_x, int *new_y,
                                  unsigned int *new_width, unsigned int *new_height);

/******* Local Variables *******/
static int compareTimes(Time t1, Time t2)
{
  Time diff;
  if (t1 == t2)
    return 0;
  diff = t1 - t2;
  return (diff < 60000) ? 1 : -1;
}

#define ON_CURRENT_WS(wwin) (wwin->frame->desktop == wwin->screen->current_desktop)

WWindow *wNextWindowToFocus(WWindow *wwin)
{
  WScreen *scr = wwin->screen;
  WWindow *tmp, *list_win = NULL, *focusable_win = NULL, *menu_win = NULL;
  WApplication *wapp, *menu_app;

  /* if window was a transient, focus the owner window */
  tmp = wWindowFor(wwin->transient_for);
  if (tmp && (!tmp->flags.mapped || WFLAGP(tmp, no_focusable))) {
    tmp = NULL;
  }

  /* search for the window of the same application, main menu of next application,
     window in focus list or andy focusable window */
  if (!tmp) {
    wapp = wApplicationOf(wwin->main_window);
    tmp = scr->focused_window;
    while (tmp) {
      if (WINDOW_LEVEL(tmp) == NSMainMenuWindowLevel) {
        // main menu could be unmapped and has skip_window_list == 1
        menu_app = wApplicationOf(tmp->main_window);
        if (menu_app && wapp && (menu_app == wapp || menu_app == wapp->next) && !menu_win)
          menu_win = tmp;
      } else if (!(tmp->flags.hidden || tmp->flags.miniaturized) &&
                 (tmp->flags.mapped || tmp->flags.shaded || !ON_CURRENT_WS(tmp))) {
        // visible or on other workspace
        if (!WFLAGP(tmp, no_focusable)) {
          // focusable
          if (!focusable_win)
            focusable_win = tmp;
          if (!WFLAGP(tmp, skip_window_list)) {
            // in window list
            if (!list_win)
              list_win = tmp;
            if ((wwin->flags.is_gnustep && !strcmp(wwin->wm_instance, tmp->wm_instance)) ||
                (!wwin->flags.is_gnustep && !strcmp(wwin->wm_class, tmp->wm_class))) {
              break;
            }
          }
        }
      }
      tmp = tmp->prev;
    }
  }

  if (!tmp) {
    if (menu_win)
      tmp = menu_win;
    else if (list_win)
      tmp = list_win;
    else if (focusable_win)
      tmp = focusable_win;
  }

  return tmp;
}

/*
 *----------------------------------------------------------------------
 * wSetFocusTo--
 *	Changes the window focus to the one passed as argument.
 * If the window to focus is not already focused, it will be brought
 * to the head of the list of windows. Previously focused window is
 * unfocused.
 *
 * Side effects:
 *	Window list may be reordered and the window focus is changed.
 *
 *----------------------------------------------------------------------
 */
void wSetFocusTo(WScreen *scr, WWindow *wwin)
{
  static WScreen *old_scr = NULL;

  WWindow *old_focused;
  WWindow *focused = scr->focused_window;
  Time timestamp = w_global.timestamp.last_event;
  WApplication *napp = NULL;
  BOOL focus_succeeded = False;

  if (scr->flags.ignore_focus_events ||
      compareTimes(w_global.timestamp.focus_change, timestamp) > 0)
    return;

  if (wwin) {
    /* Do not focus popups. */
    if (WINDOW_LEVEL(wwin) == NSPopUpMenuWindowLevel)
      return;

    if (wwin->flags.is_gnustep) {
      /* Shaded focused GNUstep window should set focus to main menu */
      if (wwin->flags.shaded) {
        WApplication *wapp = wApplicationOf(wwin->main_window);

        WMLogInfo("wSetFocusTo: Request to focus shaded GNUstep window (%lu).", wwin->client_win);
        if (!wwin->flags.focused) {  // not focused - set it
          WMLogInfo("           : Send WM_TAKE_FOCUS to shaded GNUstep window %lu.",
                    wwin->client_win);
          wClientSendProtocol(wwin, w_global.atom.wm.take_focus, timestamp);
          XFlush(dpy);
          XSync(dpy, False);
        }
        if (wapp && !wapp->gsmenu_wwin->flags.focused) {
          WMLogInfo("           : Transfer focus to main menu (%lu).",
                    wapp->gsmenu_wwin->client_win);
          wSetFocusTo(scr, wapp->gsmenu_wwin);
        }
        return;
      }
    }
  }

  wPrintWindowFocusState(wwin, "[START] wSetFocusTo:");

  if (!old_scr) {
    old_scr = scr;
  }
  old_focused = old_scr->focused_window;
  w_global.timestamp.focus_change = timestamp;

  // Focus Workspace main application menu if there's no window to focus.
  if (wwin == NULL) {
    // TDDO: hold Workspace main menu in WScreen
    WApplication *wsapp = wApplicationWithName(scr, "Workspace");
    if (wsapp && wsapp->gsmenu_wwin) {
      WMLogInfo("        wSetFocusTo: Workspace menu window: %lu", wsapp->gsmenu_wwin->client_win);
      wClientSendProtocol(wsapp->gsmenu_wwin, w_global.atom.wm.take_focus, timestamp);
      old_focused = NULL;
    }
    if (old_focused) {
      wWindowUnfocus(old_focused);
    }
    CFNotificationCenterPostNotification(scr->notificationCenter,
                                         WMDidChangeWindowFocusNotification, wwin, NULL, TRUE);
    return;
  }

  napp = wApplicationOf(wwin->main_window);

  if (old_scr != scr && old_focused) {
    wWindowUnfocus(old_focused);
  }
  /* If it's GNUstep application focus may be set to yet unmapped main menu */
  if (wwin->flags.is_gnustep || wwin->flags.mapped) {
    /* install colormap if colormap mode is lock mode */
    if (wPreferences.colormap_mode == WCM_CLICK) {
      wColormapInstallForWindow(scr, wwin);
    }
    /* set input focus */
    switch (wwin->focus_mode) {
      case WFM_NO_INPUT:  // !wm_hints->input, !WM_TAKE_FOCUS
        WMLogInfo("        wSetFocusTo: %lu focus mode == NO_INPUT. Do nothing", wwin->client_win);
        return;
      case WFM_PASSIVE:  // wm_hints->input, !WM_TAKE_FOCUS
      {
        WMLogInfo("        wSetFocusTo: %lu focus mode == PASSIVE.", wwin->client_win);
        XSetInputFocus(dpy, wwin->client_win, RevertToParent, CurrentTime);
        focus_succeeded = True;
      } break;
      case WFM_LOCALLY_ACTIVE:  // wm_hints->input, WM_TAKE_FOCUS
      {
        WMLogInfo("        wSetFocusTo: %lu focus mode == LOCALLY_ACTIVE.", wwin->client_win);
        XSetInputFocus(dpy, wwin->client_win, RevertToParent, CurrentTime);
        focus_succeeded = True;
      } break;
      case WFM_GLOBALLY_ACTIVE:  // !wm_hints->input, WM_TAKE_FOCUS
      {
        WMLogInfo("        wSetFocusTo: %lu focus mode == GLOBALLY_ACTIVE.", wwin->client_win);
        wClientSendProtocol(wwin, w_global.atom.wm.take_focus, timestamp);
        focus_succeeded = True;
      } break;
    }
  } else {
    // Non-GNUstep, not mapped (shaded, iconified)
    XSetInputFocus(dpy, scr->no_focus_win, RevertToParent, CurrentTime);
  }
  XFlush(dpy);
  XSync(dpy, False);

  /* if this is not the focused window - change the focus window list order */
  if (focused != wwin) {
    if (wwin->prev) {
      wwin->prev->next = wwin->next;
    }
    if (wwin->next) {
      wwin->next->prev = wwin->prev;
    }
    wwin->prev = focused;
    focused->next = wwin;
    wwin->next = NULL;
    scr->focused_window = wwin;

    if (napp && focus_succeeded == True && wwin != NULL) {
      wApplicationMakeFirst(napp);
      /* remember last workspace and focused window of application */
      if (wwin != napp->gsmenu_wwin) {
        napp->last_focused = wwin;
        napp->last_desktop = scr->current_desktop;
      }
    }
  }

  wWindowFocus(wwin, focused);

  old_scr = scr;
  XFlush(dpy);
  XSync(dpy, False);
  wPrintWindowFocusState(wwin, "[ END ] wSetFocusTo:");
}

void wShadeWindow(WWindow *wwin)
{
  if (wwin->flags.shaded)
    return;

    /* XLowerWindow(dpy, wwin->client_win); */
#ifdef USE_ANIMATIONS
  wAnimateShade(wwin, SHADE);
#endif

  wwin->flags.skip_next_animation = 0;
  wwin->flags.shaded = 1;
  wwin->flags.mapped = 0;
  /* prevent window withdrawal when getting UnmapNotify */
  XSelectInput(dpy, wwin->client_win, wwin->event_mask & ~StructureNotifyMask);
  XUnmapWindow(dpy, wwin->client_win);
  XSelectInput(dpy, wwin->client_win, wwin->event_mask);

  /* for the client it's just like iconification */
  wFrameWindowResize(wwin->frame, wwin->frame->core->width, wwin->frame->top_width - 1);

  wwin->client.y = wwin->frame_y - wwin->client.height + wwin->frame->top_width;
  wWindowSynthConfigureNotify(wwin);

  wClientSetState(wwin, IconicState, None);

  if (wwin->flags.focused) {
    wSetFocusTo(wwin->screen, wwin);
  }

  CFMutableDictionaryRef info = CFDictionaryCreateMutable(
      kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(info, CFSTR("state"), CFSTR("shade"));
  CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                       WMDidChangeWindowStateNotification, wwin, info, TRUE);
  CFRelease(info);

#ifdef USE_ANIMATIONS
  if (!wwin->screen->flags.startup) {
    /* Catch up with events not processed while animation was running */
    ProcessPendingEvents();
  }
#endif
}

void wUnshadeWindow(WWindow *wwin)
{
  if (!wwin->flags.shaded)
    return;

  wwin->flags.shaded = 0;
  wwin->flags.mapped = 1;
  XMapWindow(dpy, wwin->client_win);

#ifdef USE_ANIMATIONS
  wAnimateShade(wwin, UNSHADE);
#endif

  wwin->flags.skip_next_animation = 0;
  wFrameWindowResize(wwin->frame, wwin->frame->core->width,
                     wwin->frame->top_width + wwin->client.height + wwin->frame->bottom_width);

  wwin->client.y = wwin->frame_y + wwin->frame->top_width;
  wWindowSynthConfigureNotify(wwin);

  wClientSetState(wwin, NormalState, None);

  /* if the window is focused, set the focus again as it was disabled during
   * shading */
  /* if (wwin->flags.focused || wwin == wApplicationOf(wwin->main_window)->last_focused) { */
  if (wwin->flags.focused) {
    wSetFocusTo(wwin->screen, wwin);
  }

  CFMutableDictionaryRef info = CFDictionaryCreateMutable(
      kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(info, CFSTR("state"), CFSTR("shade"));
  CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                       WMDidChangeWindowStateNotification, wwin, info, TRUE);
  CFRelease(info);
}

/* Set the old coordinates using the current values */
static void _saveOldWindowGeometry(WWindow *wwin, int directions)
{
  /* never been saved? */
  if (!wwin->old_geometry.width)
    directions |= SAVE_GEOMETRY_X | SAVE_GEOMETRY_WIDTH;
  if (!wwin->old_geometry.height)
    directions |= SAVE_GEOMETRY_Y | SAVE_GEOMETRY_HEIGHT;

  if (directions & SAVE_GEOMETRY_X)
    wwin->old_geometry.x = wwin->frame_x;
  if (directions & SAVE_GEOMETRY_Y)
    wwin->old_geometry.y = wwin->frame_y;
  if (directions & SAVE_GEOMETRY_WIDTH)
    wwin->old_geometry.width = wwin->client.width;
  if (directions & SAVE_GEOMETRY_HEIGHT)
    wwin->old_geometry.height = wwin->client.height;
}

static void _getWindowGeometry(WWindow *wwin, int *x, int *y, int *w, int *h)
{
  WMRect old_geom_rect;
  int old_head;
  Bool same_head;

  old_geom_rect = WMMakeRect(wwin->old_geometry.x, wwin->old_geometry.y, wwin->old_geometry.width,
                             wwin->old_geometry.height);
  old_head = wGetHeadForRect(wwin->screen, old_geom_rect);
  same_head = (wGetHeadForWindow(wwin) == old_head);
  *x = ((wwin->old_geometry.x || wwin->old_geometry.width) && same_head) ? wwin->old_geometry.x
                                                                         : wwin->frame_x;
  *y = ((wwin->old_geometry.y || wwin->old_geometry.height) && same_head) ? wwin->old_geometry.y
                                                                          : wwin->frame_y;
  *w = wwin->old_geometry.width ? wwin->old_geometry.width : wwin->client.width;
  *h = wwin->old_geometry.height ? wwin->old_geometry.height : wwin->client.height;
}

/* Remember geometry for unmaximizing */
void wUpdateSavedWindowGeometry(WWindow *wwin)
{
  /* NOT if we aren't already maximized
   * we'll save geometry when maximizing */
  if (!wwin->flags.maximized)
    return;

  /* NOT if we are fully maximized */
  if ((wwin->flags.maximized & MAX_MAXIMUS) ||
      ((wwin->flags.maximized & MAX_HORIZONTAL) && (wwin->flags.maximized & MAX_VERTICAL)))
    return;

  /* save the co-ordinate in the axis in which we AREN'T maximized */
  if (wwin->flags.maximized & MAX_HORIZONTAL)
    _saveOldWindowGeometry(wwin, SAVE_GEOMETRY_Y);
  if (wwin->flags.maximized & MAX_VERTICAL)
    _saveOldWindowGeometry(wwin, SAVE_GEOMETRY_X);
}

/* Perform maximization despite the current window state */
void wMaximizeWindow(WWindow *wwin, int directions)
{
  unsigned int new_width, new_height, half_scr_width, half_scr_height;
  int new_x = 0;
  int new_y = 0;
  int maximus_x = 0;
  int maximus_y = 0;
  unsigned int maximus_width = 0;
  unsigned int maximus_height = 0;
  WArea usableArea, totalArea;
  Bool has_border = 1;
  int adj_size;
  WScreen *scr = wwin->screen;

  if (!IS_RESIZABLE(wwin))
    return;

  if (!HAS_BORDER(wwin))
    has_border = 0;

  if (wPreferences.drag_maximized_window == DRAGMAX_NOMOVE)
    wwin->client_flags.no_movable = 1;

  /* the size to adjust the geometry */
  adj_size = scr->frame_border_width * 2 * has_border;

  /* save old coordinates before we change the current values */
  if (!wwin->flags.maximized)
    _saveOldWindowGeometry(wwin, SAVE_GEOMETRY_ALL);

  totalArea.x2 = scr->width;
  totalArea.y2 = scr->height;
  totalArea.x1 = 0;
  totalArea.y1 = 0;
  usableArea = totalArea;

  if (!(directions & MAX_IGNORE_XINERAMA)) {
    WScreen *scr = wwin->screen;
    int head;

    if (directions & MAX_KEYBOARD)
      head = wGetHeadForWindow(wwin);
    else
      head = wGetHeadForPointerLocation(scr);

    usableArea = wGetUsableAreaForHead(scr, head, &totalArea, True);
  }

  /* Only save directions, not kbd or xinerama hints */
  directions &= (MAX_HORIZONTAL | MAX_VERTICAL | MAX_LEFTHALF | MAX_RIGHTHALF | MAX_TOPHALF |
                 MAX_BOTTOMHALF | MAX_MAXIMUS);

  if (WFLAGP(wwin, full_maximize)) {
    usableArea = totalArea;
  }
  half_scr_width = (usableArea.x2 - usableArea.x1) / 2;
  half_scr_height = (usableArea.y2 - usableArea.y1) / 2;

  if (wwin->flags.shaded) {
    wwin->flags.skip_next_animation = 1;
    wUnshadeWindow(wwin);
  }

  if (directions & MAX_MAXIMUS) {
    find_Maximus_geometry(wwin, usableArea, &maximus_x, &maximus_y, &maximus_width,
                          &maximus_height);
    new_width = maximus_width - adj_size;
    new_height = maximus_height - adj_size;
    new_x = maximus_x;
    new_y = maximus_y;
    if (WFLAGP(wwin, full_maximize) && (new_y == 0)) {
      new_height += wwin->frame->bottom_width - 1;
      new_y -= wwin->frame->top_width;
    }
    wwin->maximus_x = new_x;
    wwin->maximus_y = new_y;
    wwin->flags.old_maximized |= MAX_MAXIMUS;
  } else {
    /* set default values if no option set then */
    if (!(directions & (MAX_HORIZONTAL | MAX_LEFTHALF | MAX_RIGHTHALF | MAX_MAXIMUS))) {
      new_width = (wwin->old_geometry.width) ? wwin->old_geometry.width : wwin->frame->core->width;
      new_x = (wwin->old_geometry.x) ? wwin->old_geometry.x : wwin->frame_x;
    }
    if (!(directions & (MAX_VERTICAL | MAX_TOPHALF | MAX_BOTTOMHALF | MAX_MAXIMUS))) {
      new_height =
          (wwin->old_geometry.height) ? wwin->old_geometry.height : wwin->frame->core->height;
      new_y = (wwin->old_geometry.y) ? wwin->old_geometry.y : wwin->frame_y;
    }

    /* left|right position */
    if (directions & MAX_LEFTHALF) {
      new_width = half_scr_width - adj_size;
      new_x = usableArea.x1;
    } else if (directions & MAX_RIGHTHALF) {
      new_width = half_scr_width - adj_size;
      new_x = usableArea.x1 + half_scr_width;
    }
    /* top|bottom position */
    if (directions & MAX_TOPHALF) {
      new_height = half_scr_height - adj_size;
      new_y = usableArea.y1;
    } else if (directions & MAX_BOTTOMHALF) {
      new_height = half_scr_height - adj_size;
      new_y = usableArea.y1 + half_scr_height;
    }

    /* vertical|horizontal position */
    if (directions & MAX_HORIZONTAL) {
      new_width = usableArea.x2 - usableArea.x1 - adj_size;
      new_x = usableArea.x1;
    }
    if (directions & MAX_VERTICAL) {
      new_height = usableArea.y2 - usableArea.y1 - adj_size;
      new_y = usableArea.y1;
      if (WFLAGP(wwin, full_maximize) && (new_y == 0)) {
        new_y -= wwin->frame->top_width;
      }
    }
  }

  if (!WFLAGP(wwin, full_maximize) &&
      !(directions == MAX_MAXIMUS || directions == MAX_HORIZONTAL)) {
    new_height -= wwin->frame->top_width + wwin->frame->bottom_width;
  }

  /* set maximization state */
  wwin->flags.maximized = directions;
  if ((wwin->flags.old_maximized & MAX_MAXIMUS) && !wwin->flags.maximized) {
    wwin->flags.maximized = MAX_MAXIMUS;
  }
  wWindowConstrainSize(wwin, &new_width, &new_height);
  wWindowCropSize(wwin, usableArea.x2 - usableArea.x1, usableArea.y2 - usableArea.y1, &new_width,
                  &new_height);

  wWindowConfigure(wwin, new_x, new_y, new_width, new_height);
  wWindowSynthConfigureNotify(wwin);

  CFMutableDictionaryRef info = CFDictionaryCreateMutable(
      kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(info, CFSTR("state"), CFSTR("maximize"));
  CFNotificationCenterPostNotification(scr->notificationCenter,
                                       WMDidChangeWindowStateNotification, wwin, info, TRUE);
  CFRelease(info);
}

/* If window maximized - unmaximize. Maximize it otherwise. */
/* void wMaximizeOrRestoreWindow(WWindow *wwin, int directions) */
void handleMaximize(WWindow *wwin, int directions)
{
  int current = wwin->flags.maximized;
  int requested = directions & (MAX_HORIZONTAL | MAX_VERTICAL | MAX_LEFTHALF | MAX_RIGHTHALF |
                                MAX_TOPHALF | MAX_BOTTOMHALF | MAX_MAXIMUS);
  int effective = requested ^ current;
  int flags = directions & ~requested;

  if (!effective) {
    /* allow wMaximizeWindow to restore the Maximusized size */
    if ((wwin->flags.old_maximized & MAX_MAXIMUS) && !(requested & MAX_MAXIMUS)) {
      wMaximizeWindow(wwin, MAX_MAXIMUS | flags);
    } else {
      wUnmaximizeWindow(wwin);
    }
    /* these alone mean vertical|horizontal toggle */
  } else if ((effective == MAX_LEFTHALF) || (effective == MAX_RIGHTHALF) ||
             (effective == MAX_TOPHALF) || (effective == MAX_BOTTOMHALF)) {
    wUnmaximizeWindow(wwin);
  } else {
    if ((requested == (MAX_HORIZONTAL | MAX_VERTICAL)) || (requested == MAX_MAXIMUS))
      effective = requested;
    else {
      if (requested & MAX_LEFTHALF) {
        if (!(requested & (MAX_TOPHALF | MAX_BOTTOMHALF))) {
          effective |= MAX_VERTICAL;
        } else {
          effective |= requested & (MAX_TOPHALF | MAX_BOTTOMHALF);
        }
        effective |= MAX_LEFTHALF;
        effective &= ~(MAX_HORIZONTAL | MAX_RIGHTHALF);
      } else if (requested & MAX_RIGHTHALF) {
        if (!(requested & (MAX_TOPHALF | MAX_BOTTOMHALF))) {
          effective |= MAX_VERTICAL;
        } else {
          effective |= requested & (MAX_TOPHALF | MAX_BOTTOMHALF);
        }
        effective |= MAX_RIGHTHALF;
        effective &= ~(MAX_HORIZONTAL | MAX_LEFTHALF);
      }
      if (requested & MAX_TOPHALF) {
        if (!(requested & (MAX_LEFTHALF | MAX_RIGHTHALF))) {
          effective |= MAX_HORIZONTAL;
        } else {
          effective |= requested & (MAX_LEFTHALF | MAX_RIGHTHALF);
        }
        effective |= MAX_TOPHALF;
        effective &= ~(MAX_VERTICAL | MAX_BOTTOMHALF);
      } else if (requested & MAX_BOTTOMHALF) {
        if (!(requested & (MAX_LEFTHALF | MAX_RIGHTHALF))) {
          effective |= MAX_HORIZONTAL;
        } else {
          effective |= requested & (MAX_LEFTHALF | MAX_RIGHTHALF);
        }
        effective |= MAX_BOTTOMHALF;
        effective &= ~(MAX_VERTICAL | MAX_TOPHALF);
      }
      if (requested & MAX_HORIZONTAL) {
        effective &= ~(MAX_LEFTHALF | MAX_RIGHTHALF);
      }
      if (requested & MAX_VERTICAL) {
        effective &= ~(MAX_TOPHALF | MAX_BOTTOMHALF);
      }
      effective &= ~MAX_MAXIMUS;
    }
    wMaximizeWindow(wwin, effective | flags);
  }
}

/* the window boundary coordinates */
typedef struct {
  int left;
  int right;
  int bottom;
  int top;
  int width;
  int height;
} win_coords;

static void set_window_coords(WWindow *wwin, win_coords *obs)
{
  obs->left = wwin->frame_x;
  obs->top = wwin->frame_y;
  obs->width = wwin->frame->core->width;
  obs->height = wwin->frame->core->height;
  obs->bottom = obs->top + obs->height;
  obs->right = obs->left + obs->width;
}

/*
 * Maximus: tiled maximization (maximize without overlapping other windows)
 *
 * The original window 'orig' will be maximized to new coordinates 'new'.
 * The windows obstructing the maximization of 'orig' are denoted 'obs'.
 */
static void find_Maximus_geometry(WWindow *wwin, WArea usableArea, int *new_x, int *new_y,
                                  unsigned int *new_width, unsigned int *new_height)
{
  WWindow *tmp;
  short int tbar_height_0 = 0, rbar_height_0 = 0, bd_width_0 = 0;
  short int adjust_height;
  int x_intsect, y_intsect;
  /* the obstructing, original and new windows */
  win_coords obs, orig, new;

  /* set the original coordinate positions of the window to be Maximumized */
  if (wwin->flags.maximized) {
    /* window is already maximized; consider original geometry */
    _getWindowGeometry(wwin, &orig.left, &orig.top, &orig.width, &orig.height);
    orig.bottom = orig.top + orig.height;
    orig.right = orig.left + orig.width;
  } else
    set_window_coords(wwin, &orig);

  /* Try to fully maximize first, then readjust later */
  new.left = usableArea.x1;
  new.right = usableArea.x2;
  new.top = usableArea.y1;
  new.bottom = usableArea.y2;

  if (HAS_TITLEBAR(wwin))
    tbar_height_0 = TITLEBAR_HEIGHT;
  if (HAS_RESIZEBAR(wwin))
    rbar_height_0 = RESIZEBAR_HEIGHT;
  if (HAS_BORDER(wwin))
    bd_width_0 = wwin->screen->frame_border_width;

  /* the length to be subtracted if the window has titlebar, etc */
  adjust_height = tbar_height_0 + 2 * bd_width_0 + rbar_height_0;

  tmp = wwin;
  /* The focused window is always the last in the list */
  while (tmp->prev) {
    /* ignore windows in other workspaces etc */
    if (tmp->prev->frame->desktop != wwin->screen->current_desktop ||
        tmp->prev->flags.miniaturized || tmp->prev->flags.hidden) {
      tmp = tmp->prev;
      continue;
    }
    tmp = tmp->prev;

    /* Set the coordinates of obstructing window */
    set_window_coords(tmp, &obs);

    /* Try to maximize in the y direction first */
    x_intsect = calcIntersectionLength(orig.left, orig.width, obs.left, obs.width);
    if (x_intsect != 0) {
      /* TODO: Consider the case when coords are equal */
      if (obs.bottom < orig.top && obs.bottom > new.top) {
        /* w_0 is below the bottom of w_j */
        new.top = obs.bottom + 1;
      }
      if (orig.bottom < obs.top && obs.top < new.bottom) {
        /* The bottom of w_0 is above the top of w_j */
        new.bottom = obs.top - 1;
      }
    }
  }

  tmp = wwin;
  while (tmp->prev) {
    if (tmp->prev->frame->desktop != wwin->screen->current_desktop ||
        tmp->prev->flags.miniaturized || tmp->prev->flags.hidden) {
      tmp = tmp->prev;
      continue;
    }
    tmp = tmp->prev;

    set_window_coords(tmp, &obs);

    /*
     * Use the new.top and new.height instead of original values
     * as they may have different intersections with the obstructing windows
     */
    new.height = new.bottom - new.top - adjust_height;
    y_intsect = calcIntersectionLength(new.top, new.height, obs.top, obs.height);
    if (y_intsect != 0) {
      if (obs.right < orig.left && obs.right > new.left) {
        /* w_0 is completely to the right of w_j */
        new.left = obs.right + 1;
      }
      if (orig.right < obs.left && obs.left < new.right) {
        /* w_0 is completely to the left of w_j */
        new.right = obs.left - 1;
      }
    }
  }

  *new_x = new.left;
  *new_y = new.top;
  /* xcalc needs -7 here, but other apps don't */
  *new_height = new.bottom - new.top - adjust_height - 1;
  *new_width = new.right - new.left;
}

void wUnmaximizeWindow(WWindow *wwin)
{
  int x, y, w, h;

  if (!wwin->flags.maximized)
    return;

  if (wwin->flags.shaded) {
    wwin->flags.skip_next_animation = 1;
    wUnshadeWindow(wwin);
  }

  if (wPreferences.drag_maximized_window == DRAGMAX_NOMOVE)
    wwin->client_flags.no_movable = 0;

  /* Use old coordinates if they are set, current values otherwise */
  _getWindowGeometry(wwin, &x, &y, &w, &h);

  /* unMaximusize relative to original position */
  if (wwin->flags.maximized & MAX_MAXIMUS) {
    x += wwin->frame_x - wwin->maximus_x;
    y += wwin->frame_y - wwin->maximus_y;
  }

  wwin->flags.maximized = 0;
  wwin->flags.old_maximized = 0;
  wWindowConfigure(wwin, x, y, w, h);
  wWindowSynthConfigureNotify(wwin);

  CFMutableDictionaryRef info = CFDictionaryCreateMutable(
      kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(info, CFSTR("state"), CFSTR("maximize"));
  CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                       WMDidChangeWindowStateNotification, wwin, info, TRUE);
  CFRelease(info);
}

void wFullscreenWindow(WWindow *wwin)
{
  int head;
  WMRect rect;

  if (wwin->flags.fullscreen)
    return;

  wwin->flags.fullscreen = True;

  wWindowConfigureBorders(wwin);

  ChangeStackingLevel(wwin->frame->core, NSNormalWindowLevel);
  wRaiseFrame(wwin->frame->core);

  wwin->bfs_geometry.x = wwin->frame_x;
  wwin->bfs_geometry.y = wwin->frame_y;
  wwin->bfs_geometry.width = wwin->frame->core->width;
  wwin->bfs_geometry.height = wwin->frame->core->height;

  head = wGetHeadForWindow(wwin);
  rect = wGetRectForHead(wwin->screen, head);
  wWindowConfigure(wwin, rect.pos.x, rect.pos.y, rect.size.width, rect.size.height);

  wwin->screen->bfs_focused_window = wwin->screen->focused_window;
  wSetFocusTo(wwin->screen, wwin);

  CFMutableDictionaryRef info = CFDictionaryCreateMutable(
      kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(info, CFSTR("state"), CFSTR("fullscreen"));
  CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                       WMDidChangeWindowStateNotification, wwin, info, TRUE);
  CFRelease(info);
}

void wUnfullscreenWindow(WWindow *wwin)
{
  if (!wwin->flags.fullscreen)
    return;

  wwin->flags.fullscreen = False;

  if (WFLAGP(wwin, sunken))
    ChangeStackingLevel(wwin->frame->core, NSSunkenWindowLevel);
  else if (WFLAGP(wwin, floating))
    ChangeStackingLevel(wwin->frame->core, NSFloatingWindowLevel);

  wWindowConfigure(wwin, wwin->bfs_geometry.x, wwin->bfs_geometry.y, wwin->bfs_geometry.width,
                   wwin->bfs_geometry.height);

  wWindowConfigureBorders(wwin);
  /*
  // seems unnecessary, but also harmless (doesn't generate flicker) -Dan
  wFrameWindowPaint(wwin->frame);
  */

  CFMutableDictionaryRef info = CFDictionaryCreateMutable(
      kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(info, CFSTR("state"), CFSTR("fullscreen"));
  CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                       WMDidChangeWindowStateNotification, wwin, info, TRUE);
  CFRelease(info);

  if (wwin->screen->bfs_focused_window) {
    wSetFocusTo(wwin->screen, wwin->screen->bfs_focused_window);
    wwin->screen->bfs_focused_window = NULL;
  }
}

static void flushExpose(void)
{
  XEvent tmpev;

  while (XCheckTypedEvent(dpy, Expose, &tmpev))
    WMHandleEvent(&tmpev);
  XSync(dpy, 0);
}

static void unmapTransientsFor(WWindow *wwin)
{
  WWindow *tmp;

  tmp = wwin->screen->focused_window;
  while (tmp) {
    /* unmap the transients for this transient */
    if (tmp != wwin && tmp->transient_for == wwin->client_win &&
        (tmp->flags.mapped || wwin->screen->flags.startup || tmp->flags.shaded)) {
      unmapTransientsFor(tmp);
      tmp->flags.miniaturized = 1;
      if (!tmp->flags.shaded)
        wWindowUnmap(tmp);
      else
        XUnmapWindow(dpy, tmp->frame->core->window);
      /*
        if (!tmp->flags.shaded)
      */
      wClientSetState(tmp, IconicState, None);

      CFMutableDictionaryRef info = CFDictionaryCreateMutable(
          kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
      CFDictionaryAddValue(info, CFSTR("state"), CFSTR("iconify-transient"));
      CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                           WMDidChangeWindowStateNotification, wwin, info, TRUE);
      CFRelease(info);
    }
    tmp = tmp->prev;
  }
}

static void mapTransientsFor(WWindow *wwin)
{
  WWindow *tmp;

  tmp = wwin->screen->focused_window;
  while (tmp) {
    /* recursively map the transients for this transient */
    if (tmp != wwin && tmp->transient_for == wwin->client_win &&
        /*!tmp->flags.mapped */ tmp->flags.miniaturized && tmp->icon == NULL) {
      mapTransientsFor(tmp);
      tmp->flags.miniaturized = 0;
      if (!tmp->flags.shaded)
        wWindowMap(tmp);
      else
        XMapWindow(dpy, tmp->frame->core->window);
      tmp->flags.semi_focused = 0;
      /*
        if (!tmp->flags.shaded)
      */
      wClientSetState(tmp, NormalState, None);

      CFMutableDictionaryRef info = CFDictionaryCreateMutable(
          kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
      CFDictionaryAddValue(info, CFSTR("state"), CFSTR("iconify-transient"));
      CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                           WMDidChangeWindowStateNotification, wwin, info, TRUE);
      CFRelease(info);
    }
    tmp = tmp->prev;
  }
}

static WWindow *recursiveTransientFor(WWindow *wwin)
{
  int i;

  if (!wwin)
    return None;

  /* hackish way to detect transient_for cycle */
  i = wwin->screen->window_count + 1;

  while (wwin && wwin->transient_for != None && i > 0) {
    wwin = wWindowFor(wwin->transient_for);
    i--;
  }
  if (i == 0 && wwin) {
    WMLogWarning(_("window \"%s\" has a severely broken WM_TRANSIENT_FOR hint"),
                 wwin->frame->title);
    return NULL;
  }

  return wwin;
}

void wIconifyWindow(WWindow *wwin)
{
  XWindowAttributes attribs;
  int present;

  if (!XGetWindowAttributes(dpy, wwin->client_win, &attribs))
    return; /* the window doesn't exist anymore */

  if (wwin->flags.miniaturized)
    return; /* already miniaturized */

  if (wwin->transient_for != None && wwin->transient_for != wwin->screen->root_win) {
    WWindow *owner = wWindowFor(wwin->transient_for);

    if (owner && owner->flags.miniaturized)
      return;
  }

  present = wwin->frame->desktop == wwin->screen->current_desktop;

  /* if the window is in another workspace, simplify process */
  if (present) {
    /* icon creation may take a while */
    XGrabPointer(dpy, wwin->screen->root_win, False, ButtonMotionMask | ButtonReleaseMask,
                 GrabModeAsync, GrabModeAsync, None, None, CurrentTime);
  }

  if (!wPreferences.disable_miniwindows && !wwin->flags.net_handle_icon) {
    if (!wwin->flags.icon_moved)
      PlaceIcon(wwin->screen, &wwin->icon_x, &wwin->icon_y, wGetHeadForWindow(wwin));

    wwin->icon = icon_create_for_wwindow(wwin);

    /* extract the window screenshot everytime, as the option can be enable anytime */
    if (wwin->client_win && wwin->flags.mapped) {
      RImage *mini_preview;
      XImage *pimg;
      unsigned int w, h;
      int x, y;
      Window baz;

      XRaiseWindow(dpy, wwin->frame->core->window);
      XTranslateCoordinates(dpy, wwin->client_win, wwin->screen->root_win, 0, 0, &x, &y, &baz);

      w = attribs.width;
      h = attribs.height;

      if (x - attribs.x + attribs.width > wwin->screen->width)
        w = wwin->screen->width - x + attribs.x;

      if (y - attribs.y + attribs.height > wwin->screen->height)
        h = wwin->screen->height - y + attribs.y;

      pimg = XGetImage(dpy, wwin->client_win, 0, 0, w, h, AllPlanes, ZPixmap);
      if (pimg) {
        mini_preview = RCreateImageFromXImage(wwin->screen->rcontext, pimg, NULL);
        XDestroyImage(pimg);

        if (mini_preview) {
          set_icon_minipreview(wwin->icon, mini_preview);
          RReleaseImage(mini_preview);
        } else {
          const char *title;
          char title_buf[32];

          if (wwin->frame->title) {
            title = wwin->frame->title;
          } else {
            snprintf(title_buf, sizeof(title_buf), "(id=0x%lx)", wwin->client_win);
            title = title_buf;
          }
          WMLogWarning(_("creation of mini-preview failed for window \"%s\""), title);
        }
      }
    }
  }

  wwin->flags.miniaturized = 1;
  wwin->flags.mapped = 0;

  /* unmap transients */
  unmapTransientsFor(wwin);

  if (present) {
#ifdef USE_ANIMATIONS
    int ix, iy, iw, ih;
#endif
    XUngrabPointer(dpy, CurrentTime);
    wWindowUnmap(wwin);
    /* let all Expose events arrive so that we can repaint
     * something before the animation starts (and the server is grabbed) */
    XSync(dpy, 0);

    if (wPreferences.disable_miniwindows || wwin->flags.net_handle_icon)
      wClientSetState(wwin, IconicState, None);
    else
      wClientSetState(wwin, IconicState, wwin->icon->icon_win);

    flushExpose();
#ifdef USE_ANIMATIONS
    if (wGetAnimationGeometry(wwin, &ix, &iy, &iw, &ih))
      wAnimateResize(wwin->screen, wwin->frame_x, wwin->frame_y, wwin->frame->core->width,
                     wwin->frame->core->height, ix, iy, iw, ih);
#endif
  }

  wwin->flags.skip_next_animation = 0;

  if (!wPreferences.disable_miniwindows && !wwin->flags.net_handle_icon) {
    if ((wwin->screen->current_desktop == wwin->frame->desktop || IS_OMNIPRESENT(wwin) ||
         wPreferences.sticky_icons) &&
        wwin->screen->flags.icon_yard_mapped) {
      XMapWindow(dpy, wwin->icon->core->window);
      wwin->icon->mapped = 1;
    }

    AddToStackList(wwin->icon->core);
    wLowerFrame(wwin->icon->core);
  }

  if (present) {
    WWindow *owner = recursiveTransientFor(wwin->screen->focused_window);

    /*
     * It doesn't seem to be working and causes button event hangup
     * when deiconifying a transient window.
     setupIconGrabs(wwin->icon);
    */
    if ((wwin->flags.focused || (owner && wwin->client_win == owner->client_win))) {
      wSetFocusTo(wwin->screen, wNextWindowToFocus(wwin));
    }
#ifdef USE_ANIMATIONS
    if (!wwin->screen->flags.startup) {
      /* Catch up with events not processed while animation was running */
      Window clientwin = wwin->client_win;
      ProcessPendingEvents();
      /* the window can disappear while ProcessPendingEvents() runs */
      if (!wWindowFor(clientwin))
        return;
    }
#endif
  }

  /* maybe we want to do this regardless of net_handle_icon
   * it seems to me we might break behaviour this way.
   */
  if (wwin->flags.selected && !wPreferences.disable_miniwindows && !wwin->flags.net_handle_icon)
    wIconSelect(wwin->icon);

  CFMutableDictionaryRef info = CFDictionaryCreateMutable(
      kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(info, CFSTR("state"), CFSTR("iconify"));
  CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                       WMDidChangeWindowStateNotification, wwin, info, TRUE);
  CFRelease(info);

  if (wPreferences.auto_arrange_icons)
    wArrangeIcons(wwin->screen, True);
}

void wDeiconifyWindow(WWindow *wwin)
{
  /* Let's avoid changing workspace while deiconifying */
  w_global.ignore_desktop_change = True;

  /* we're hiding for show_desktop */
  int netwm_hidden =
      wwin->flags.net_show_desktop && wwin->frame->desktop != wwin->screen->current_desktop;

  if (!netwm_hidden)
    wWindowChangeDesktop(wwin, wwin->screen->current_desktop);

  if (!wwin->flags.miniaturized) {
    w_global.ignore_desktop_change = False;
    return;
  }

  if (wwin->transient_for != None && wwin->transient_for != wwin->screen->root_win) {
    WWindow *owner = recursiveTransientFor(wwin);

    if (owner && owner->flags.miniaturized) {
      wDeiconifyWindow(owner);
      wSetFocusTo(wwin->screen, wwin);
      wRaiseFrame(wwin->frame->core);
      w_global.ignore_desktop_change = False;
      return;
    }
  }

  wwin->flags.miniaturized = 0;

  if (!netwm_hidden && !wwin->flags.shaded)
    wwin->flags.mapped = 1;

  if (!netwm_hidden || wPreferences.sticky_icons) {
    /* maybe we want to do this regardless of net_handle_icon
     * it seems to me we might break behaviour this way.
     */
    if (!wPreferences.disable_miniwindows && !wwin->flags.net_handle_icon && wwin->icon != NULL) {
      if (wwin->icon->selected)
        wIconSelect(wwin->icon);

      XUnmapWindow(dpy, wwin->icon->core->window);
    }
  }

  /* if the window is in another workspace, do it silently */
  if (!netwm_hidden) {
#ifdef USE_ANIMATIONS
    int ix, iy, iw, ih;
    if (wGetAnimationGeometry(wwin, &ix, &iy, &iw, &ih))
      wAnimateResize(wwin->screen, ix, iy, iw, ih, wwin->frame_x, wwin->frame_y,
                     wwin->frame->core->width, wwin->frame->core->height);
#endif
    wwin->flags.skip_next_animation = 0;
    XGrabServer(dpy);
    if (!wwin->flags.shaded)
      XMapWindow(dpy, wwin->client_win);

    XMapWindow(dpy, wwin->frame->core->window);
    wRaiseFrame(wwin->frame->core);
    if (!wwin->flags.shaded)
      wClientSetState(wwin, NormalState, None);

    mapTransientsFor(wwin);
  }

  if (!wPreferences.disable_miniwindows && wwin->icon != NULL && !wwin->flags.net_handle_icon) {
    RemoveFromStackList(wwin->icon->core);
    wSetFocusTo(wwin->screen, wwin);
    wIconDestroy(wwin->icon);
    wwin->icon = NULL;
  }

  if (!netwm_hidden) {
    XUngrabServer(dpy);

    wSetFocusTo(wwin->screen, wwin);

#ifdef USE_ANIMATIONS
    if (!wwin->screen->flags.startup) {
      /* Catch up with events not processed while animation was running */
      Window clientwin = wwin->client_win;

      ProcessPendingEvents();

      /* the window can disappear while ProcessPendingEvents() runs */
      if (!wWindowFor(clientwin)) {
        w_global.ignore_desktop_change = False;
        return;
      }
    }
#endif
  }

  if (wPreferences.auto_arrange_icons)
    wArrangeIcons(wwin->screen, True);

  CFMutableDictionaryRef info = CFDictionaryCreateMutable(
      kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(info, CFSTR("state"), CFSTR("iconify"));
  CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                       WMDidChangeWindowStateNotification, wwin, info, TRUE);
  CFRelease(info);

  /* In case we were shaded and iconified, also unshade */
  if (!netwm_hidden)
    wUnshadeWindow(wwin);

  w_global.ignore_desktop_change = False;
}

void wHideAll(WScreen *scr)
{
  WWindow *wwin;
  WWindow **windows;
  WMenu *menu;
  unsigned int wcount = 0;
  int i;

  if (!scr)
    return;

  menu = scr->switch_menu;

  windows = wmalloc(sizeof(WWindow *));

  if (menu != NULL) {
    for (i = 0; i < menu->items_count; i++) {
      windows[wcount] = (WWindow *)menu->items[i]->clientdata;
      wcount++;
      windows = wrealloc(windows, sizeof(WWindow *) * (wcount + 1));
    }
  } else {
    wwin = scr->focused_window;

    while (wwin) {
      windows[wcount] = wwin;
      wcount++;
      windows = wrealloc(windows, sizeof(WWindow *) * (wcount + 1));
      wwin = wwin->prev;
    }
  }

  for (i = 0; i < wcount; i++) {
    wwin = windows[i];
    if (wwin->frame->desktop == scr->current_desktop &&
        !(wwin->flags.miniaturized || wwin->flags.hidden) && !wwin->flags.internal_window &&
        !WFLAGP(wwin, no_miniaturizable)) {
      wwin->flags.skip_next_animation = 1;
      if (wwin->protocols.MINIATURIZE_WINDOW) {
        wClientSendProtocol(wwin, w_global.atom.gnustep.wm_miniaturize_window, CurrentTime);
      } else {
        wIconifyWindow(wwin);
      }
    }
  }

  wfree(windows);
}

static void unhideWindow(WIcon *icon, int icon_x, int icon_y, WWindow *wwin, int animate,
                         int bringToCurrentWS)
{
  if (bringToCurrentWS)
    wWindowChangeDesktop(wwin, wwin->screen->current_desktop);

  wwin->flags.hidden = 0;

#ifdef USE_ANIMATIONS
  if (!wwin->screen->flags.startup && !wPreferences.no_animations && animate) {
    wAnimateResize(wwin->screen, icon_x, icon_y, icon->core->width, icon->core->height,
                   wwin->frame_x, wwin->frame_y, wwin->frame->core->width,
                   wwin->frame->core->height);
  }
#endif
  wwin->flags.skip_next_animation = 0;
  if (wwin->screen->current_desktop == wwin->frame->desktop) {
    XMapWindow(dpy, wwin->client_win);
    XMapWindow(dpy, wwin->frame->core->window);
    wClientSetState(wwin, NormalState, None);
    wwin->flags.mapped = 1;
    wRaiseFrame(wwin->frame->core);
  }

  CFMutableDictionaryRef info = CFDictionaryCreateMutable(
      kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(info, CFSTR("state"), CFSTR("hide"));
  CFNotificationCenterPostNotification(wwin->screen->notificationCenter,
                                       WMDidChangeWindowStateNotification, wwin, info, TRUE);
  CFRelease(info);
}

void wUnhideApplication(WApplication *wapp, Bool miniwindows, Bool bringToCurrentWS)
{
  WScreen *scr;
  WWindow *wlist, *next;
  WWindow *focused = NULL;
  int animate;

  if (!wapp)
    return;

  scr = wapp->main_wwin->screen;
  wlist = scr->focused_window;
  if (!wlist)
    return;

  /* goto beginning of list */
  while (wlist->prev)
    wlist = wlist->prev;

  /* animate = !wapp->flags.skip_next_animation; */
  animate = 0;

  while (wlist) {
    next = wlist->next;

    if (wlist->main_window == wapp->main_window) {
      if (wlist->flags.focused)
        focused = wlist;
      else if (!focused || !focused->flags.focused)
        focused = wlist;

      if (wlist->flags.miniaturized) {
        if ((bringToCurrentWS || wPreferences.sticky_icons ||
             wlist->frame->desktop == scr->current_desktop) &&
            wlist->icon) {
          if (!wlist->icon->mapped) {
            int x, y;

            PlaceIcon(scr, &x, &y, wGetHeadForWindow(wlist));
            if (wlist->icon_x != x || wlist->icon_y != y)
              XMoveWindow(dpy, wlist->icon->core->window, x, y);
            wlist->icon_x = x;
            wlist->icon_y = y;
            XMapWindow(dpy, wlist->icon->core->window);
            wlist->icon->mapped = 1;
          }
          wRaiseFrame(wlist->icon->core);
        }
        if (bringToCurrentWS)
          wWindowChangeDesktop(wlist, scr->current_desktop);
        wlist->flags.hidden = 0;
        if (miniwindows && wlist->frame->desktop == scr->current_desktop)
          wDeiconifyWindow(wlist);

        CFMutableDictionaryRef info =
            CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks,
                                      &kCFTypeDictionaryValueCallBacks);
        CFDictionaryAddValue(info, CFSTR("state"), CFSTR("hide"));
        CFNotificationCenterPostNotification(scr->notificationCenter,
                                             WMDidChangeWindowStateNotification, wlist, info, TRUE);
        CFRelease(info);
      } else if (wlist->flags.shaded) {
        if (bringToCurrentWS)
          wWindowChangeDesktop(wlist, scr->current_desktop);
        wlist->flags.hidden = 0;
        wRaiseFrame(wlist->frame->core);
        if (wlist->frame->desktop == scr->current_desktop) {
          XMapWindow(dpy, wlist->frame->core->window);
          if (miniwindows)
            wUnshadeWindow(wlist);
        }

        CFMutableDictionaryRef info =
            CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks,
                                      &kCFTypeDictionaryValueCallBacks);
        CFDictionaryAddValue(info, CFSTR("state"), CFSTR("hide"));
        CFNotificationCenterPostNotification(scr->notificationCenter,
                                             WMDidChangeWindowStateNotification, wlist, info, TRUE);
        CFRelease(info);
      } else if (wlist->flags.hidden) {
        unhideWindow(wapp->app_icon->icon, wapp->app_icon->x_pos, wapp->app_icon->y_pos, wlist,
                     animate, bringToCurrentWS);
        animate = False;
      } else {
        if (bringToCurrentWS && wlist->frame->desktop != scr->current_desktop)
          wWindowChangeDesktop(wlist, scr->current_desktop);

        if (wlist->frame)
          wRaiseFrame(wlist->frame->core);
      }
    }
    wlist = next;
  }

  wapp->flags.skip_next_animation = 0;
  wapp->flags.hidden = 0;

  if (wapp->last_focused && wapp->last_focused->flags.mapped) {
    wRaiseFrame(wapp->last_focused->frame->core);
    wSetFocusTo(scr, wapp->last_focused);
  } else if (focused) {
    wSetFocusTo(scr, focused);
  }
  wapp->last_focused = NULL;
  if (wPreferences.auto_arrange_icons)
    wArrangeIcons(scr, True);

#ifdef HIDDENDOT
  wAppIconPaint(wapp->app_icon);
#endif
}

void wShowAllWindows(WScreen *scr)
{
  WWindow *wwin, *old_foc;
  WApplication *wapp;

  old_foc = wwin = scr->focused_window;
  while (wwin) {
    if (!wwin->flags.internal_window &&
        (scr->current_desktop == wwin->frame->desktop || IS_OMNIPRESENT(wwin))) {
      if (wwin->flags.miniaturized) {
        wwin->flags.skip_next_animation = 1;
        wDeiconifyWindow(wwin);
      } else if (wwin->flags.hidden) {
        wapp = wApplicationOf(wwin->main_window);
        if (wapp) {
          wUnhideApplication(wapp, False, False);
        } else {
          wwin->flags.skip_next_animation = 1;
          wDeiconifyWindow(wwin);
        }
      }
    }
    wwin = wwin->prev;
  }
  wSetFocusTo(scr, old_foc);
  /*wRaiseFrame(old_foc->frame->core); */
}

/* void wRefreshDesktop(WScreen *scr) */
/* { */
/*   Window win; */
/*   XSetWindowAttributes attr; */

/*   attr.backing_store = NotUseful; */
/*   attr.save_under = False; */
/*   win = XCreateWindow(dpy, scr->root_win, 0, 0, scr->scr_width, */
/*                       scr->scr_height, 0, CopyFromParent, CopyFromParent, */
/*                       (Visual *) CopyFromParent, CWBackingStore | CWSaveUnder, &attr); */
/*   XMapRaised(dpy, win); */
/*   XDestroyWindow(dpy, win); */
/*   XFlush(dpy); */
/* } */

void wSelectWindow(WWindow *wwin, Bool flag)
{
  WScreen *scr = wwin->screen;

  if (flag) {
    wwin->flags.selected = 1;
    if (wwin->frame->selected_border_pixel)
      XSetWindowBorder(dpy, wwin->frame->core->window, *wwin->frame->selected_border_pixel);
    else
      XSetWindowBorder(dpy, wwin->frame->core->window, scr->white_pixel);

    if (!HAS_BORDER(wwin))
      XSetWindowBorderWidth(dpy, wwin->frame->core->window, wwin->screen->frame_border_width);

    if (!scr->selected_windows) {
      scr->selected_windows = CFArrayCreateMutable(kCFAllocatorDefault, 4, NULL);
    }
    CFArrayAppendValue(scr->selected_windows, wwin);
  } else {
    wwin->flags.selected = 0;
    if (wwin->flags.focused) {
      if (wwin->frame->focused_border_pixel)
        XSetWindowBorder(dpy, wwin->frame->core->window, *wwin->frame->focused_border_pixel);
      else
        XSetWindowBorder(dpy, wwin->frame->core->window, scr->frame_focused_border_pixel);
    } else {
      if (wwin->frame->border_pixel)
        XSetWindowBorder(dpy, wwin->frame->core->window, *wwin->frame->border_pixel);
      else
        XSetWindowBorder(dpy, wwin->frame->core->window, scr->frame_border_pixel);
    }

    if (!HAS_BORDER(wwin))
      XSetWindowBorderWidth(dpy, wwin->frame->core->window, 0);

    if (scr->selected_windows) {
      CFIndex idx;
      idx = CFArrayGetFirstIndexOfValue(
          scr->selected_windows, CFRangeMake(0, CFArrayGetCount(scr->selected_windows)), wwin);
      if (idx != kCFNotFound) {
        CFArrayRemoveValueAtIndex(scr->selected_windows, idx);
      }
    }
  }
}

void wMakeWindowVisible(WWindow *wwin)
{
  Bool other_workspace = false;

  if (wwin->frame->desktop != wwin->screen->current_desktop) {
    wDesktopChange(wwin->screen, wwin->frame->desktop, wwin);
    other_workspace = true;
  }

  if (wwin->flags.shaded)
    wUnshadeWindow(wwin);

  if (wwin->flags.hidden) {
    WApplication *app;

    app = wApplicationOf(wwin->main_window);
    if (app) {
      /* trick to get focus to this window */
      app->last_focused = wwin;
      wUnhideApplication(app, False, False);
    }
  }

  if (wwin->flags.miniaturized) {
    wDeiconifyWindow(wwin);
  } else if (!other_workspace) {
    if (!WFLAGP(wwin, no_focusable))
      wSetFocusTo(wwin->screen, wwin);
    wRaiseFrame(wwin->frame->core);
  }
}
