/*  Switch between windows
 *
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 2000-2003 Alfredo K. Kojima
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

#include <stdio.h>

#include "WM.h"

#include <stdlib.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <string.h>

#include <core/wevent.h>

#include "WM.h"
#include "GNUstep.h"
#include "screen.h"
#include "window.h"
#include "framewin.h"
#include "defaults.h"
#include "actions.h"
#include "stacking.h"
#include "cycling.h"
#include "xrandr.h"
#include "switchpanel.h"

#include "dock.h"
#include <Workspace+WM.h>

/* static void raiseWindow(WSwitchPanel * swpanel, WWindow * wwin) */
/* { */
/*   Window swwin = wSwitchPanelGetWindow(swpanel); */

/*   if (wwin->flags.mapped || wwin->flags.shaded) { */
/*     if (swwin != None) { */
/*       Window win[2]; */

/*       win[0] = swwin; */
/*       win[1] = wwin->frame->core->window; */

/*       XRestackWindows(dpy, win, 2); */
/*     } else */
/*       XRaiseWindow(dpy, wwin->frame->core->window); */
/*   } */
/* } */

/* #include "event.h" */
/* static WWindow *change_focus_and_raise(WWindow *newFocused, WWindow *oldFocused, */
/* 				       WSwitchPanel *swpanel, WScreen *scr, Bool esc_cancel) */
/* { */
/*   if (!newFocused) */
/*     return oldFocused; */

/*   wWindowFocus(newFocused, oldFocused); */
/*   oldFocused = newFocused; */

/*   if (wPreferences.circ_raise && !newFocused->flags.is_gnustep) { */
/*     CommitStacking(scr); */

/*     if (!esc_cancel) */
/*       raiseWindow(swpanel, newFocused); */
/*   } */

/*   return oldFocused; */
/* } */

void SwitchWindow(WWindow *wwin, Bool cycle_inside_class)
{
  WScreen *scr = wwin->screen;
  WApplication *wapp = wApplicationOf(wwin->main_window);

  if (wapp && !cycle_inside_class) {
    wApplicationActivate(wapp);
  }
  if (wapp && wapp->flags.is_gnustep && !cycle_inside_class) {
    if (wapp->gsmenu_wwin) {
      wSetFocusTo(scr, wapp->gsmenu_wwin);
    } else {
      WSActivateApplication(scr, wwin->wm_instance);
    }
  } else if (wwin->frame) {
    wRaiseFrame(wwin->frame->core);
    CommitStacking(scr);
    if (!wwin->flags.mapped) {
      wMakeWindowVisible(wwin);
    } else {
      wSetFocusTo(scr, wwin);
    }
  } else {
    wSetFocusTo(scr, wwin);
  }
}

void StartWindozeCycle(WWindow *wwin, XEvent *event, Bool next, Bool cycle_inside_class)
{
  WShortKey binding;
  WSwitchPanel *swpanel = NULL;
  WScreen *scr = wwin->screen;
  KeyCode leftKey = XKeysymToKeycode(dpy, XK_Left);
  KeyCode rightKey = XKeysymToKeycode(dpy, XK_Right);
  KeyCode homeKey = XKeysymToKeycode(dpy, XK_Home);
  KeyCode endKey = XKeysymToKeycode(dpy, XK_End);
  KeyCode shiftLKey = XKeysymToKeycode(dpy, XK_Shift_L);
  KeyCode shiftRKey = XKeysymToKeycode(dpy, XK_Shift_R);
  KeyCode escapeKey = XKeysymToKeycode(dpy, XK_Escape);
  KeyCode returnKey = XKeysymToKeycode(dpy, XK_Return);
  Bool esc_cancel = False;
  Bool somethingElse = False;
  Bool done = False;
  Bool hasModifier;
  Bool isSwitchBack;
  int modifiers;
  WWindow *new_focused_wwin;
  XEvent ev;

  if (!wwin) {
    return;
  }

  if (next) {
    if (cycle_inside_class) {
      binding = wKeyBindings[WKBD_NEXT_WIN];
    } else {
      binding = wKeyBindings[WKBD_NEXT_APP];
    }
    isSwitchBack = False;
  } else {
    if (cycle_inside_class) {
      binding = wKeyBindings[WKBD_PREV_WIN];
    } else {
      binding = wKeyBindings[WKBD_PREV_APP];
    }
    isSwitchBack = True;
  }

  hasModifier = (binding.modifier != 0);
  if (hasModifier) {
    XGrabKeyboard(dpy, scr->root_win, False, GrabModeAsync, GrabModeAsync, CurrentTime);
  }
  scr->flags.doing_alt_tab = 1;

  if (cycle_inside_class == False) {
    swpanel = wInitSwitchPanel(scr, wwin, cycle_inside_class);
    if (wwin->flags.mapped && !wPreferences.panel_only_open) {
      /* for GNUstep apps: main menu focus that is not in window focus list */
      if (wwin->flags.is_gnustep) {
        wSwitchPanelSelectFirst(swpanel, False);
      }
      new_focused_wwin = wSwitchPanelSelectNext(swpanel, !next, True, cycle_inside_class);
    } else {
      new_focused_wwin = wSwitchPanelSelectFirst(swpanel, False);
    }
  } else {
    if (wwin->frame->desktop == scr->current_desktop) {
      new_focused_wwin = wwin;
    } else {
      new_focused_wwin = NULL;
    }
  }

  while (hasModifier && !done) {
    WMMaskEvent(dpy,
                (KeyPressMask | KeyReleaseMask | ExposureMask | PointerMotionMask |
                 ButtonReleaseMask | EnterWindowMask),
                &ev);

    /* ignore CapsLock */
    modifiers = ev.xkey.state & w_global.shortcut.modifiers_mask;

    if (!swpanel) {
      break;
    }

    switch (ev.type) {
      case KeyPress:
        if ((binding.keycode == ev.xkey.keycode && binding.modifier == modifiers) ||
            ev.xkey.keycode == rightKey || ev.xkey.keycode == leftKey) {
          if (ev.xkey.keycode == rightKey) {
            isSwitchBack = False;
          } else if (ev.xkey.keycode == leftKey) {
            isSwitchBack = True;
          }
          new_focused_wwin =
              wSwitchPanelSelectNext(swpanel, isSwitchBack, True, cycle_inside_class);
        } else if (ev.xkey.keycode == homeKey || ev.xkey.keycode == endKey) {
          new_focused_wwin = wSwitchPanelSelectFirst(swpanel, ev.xkey.keycode != homeKey);
        } else if (ev.xkey.keycode == escapeKey) {
          /* Focus the first window of the swpanel, despite the 'False' */
          // new_focused_wwin = wSwitchPanelSelectFirst(swpanel, False);
          new_focused_wwin = wwin;
          esc_cancel = True;
        } else if (ev.xkey.keycode == returnKey) {
          /* Close the switch panel without eating the keypress */
          done = True;

        } else if (ev.xkey.keycode != shiftLKey && ev.xkey.keycode != shiftRKey) {
          somethingElse = True;
          done = True;
        }
        break;

      case KeyRelease:
        if (ev.xkey.keycode == shiftLKey || ev.xkey.keycode == shiftRKey ||
            ev.xkey.keycode == leftKey || ev.xkey.keycode == rightKey ||
            ev.xkey.keycode == XK_Return) {
          break;
        } else if (ev.xkey.keycode == escapeKey) {
          done = True;
        } else if (ev.xkey.keycode != binding.keycode) {
          done = True;
        }
        break;

      case EnterNotify:
        /* ignore unwanted EnterNotify's */
        break;

      case LeaveNotify:
      case MotionNotify:
      case ButtonRelease: {
        WWindow *tmp;
        tmp = wSwitchPanelHandleEvent(swpanel, &ev);
        if (tmp) {
          new_focused_wwin = tmp;
          if (ev.type == ButtonRelease) {
            done = True;
          }
        }
      } break;

      default:
        WMHandleEvent(&ev);
        break;
    }
  }

  if (hasModifier) {
    XUngrabKeyboard(dpy, CurrentTime);
  }
  if (swpanel) {
    wSwitchPanelDestroy(swpanel);
  }

  if (new_focused_wwin && !esc_cancel) {
    SwitchWindow(new_focused_wwin, cycle_inside_class);
    // WApplication *wapp = wApplicationOf(new_focused_wwin->main_window);
    // if (wapp && !cycle_inside_class) {
    //   wApplicationActivate(wapp);
    // }
    // if (wapp && wapp->flags.is_gnustep && !cycle_inside_class) {
    //   if (wapp->gsmenu_wwin) {
    //     wSetFocusTo(scr, wapp->gsmenu_wwin);
    //   } else {
    //     WSActivateApplication(scr, new_focused_wwin->wm_instance);
    //   }
    // } else if (new_focused_wwin->frame) {
    //   wRaiseFrame(new_focused_wwin->frame->core);
    //   CommitStacking(scr);
    //   if (!new_focused_wwin->flags.mapped) {
    //     wMakeWindowVisible(new_focused_wwin);
    //   } else {
    //     wSetFocusTo(scr, new_focused_wwin);
    //   }
    // } else {
    //   wSetFocusTo(scr, new_focused_wwin);
    // }
  }

  scr->flags.doing_alt_tab = 0;

  if (somethingElse) {
    WMHandleEvent(&ev);
  }
}
