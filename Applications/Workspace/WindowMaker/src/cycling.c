/* cycling.c- window cycling
 *
 *  Window Maker window manager
 *
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

#include "wconfig.h"

#include <stdlib.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

#include "WindowMaker.h"
#include "GNUstep.h"
#include "screen.h"
#include "window.h"
#include "framewin.h"
#include "keybind.h"
#include "actions.h"
#include "stacking.h"
#include "cycling.h"
#include "xinerama.h"
#include "switchpanel.h"


static void raiseWindow(WSwitchPanel * swpanel, WWindow * wwin)
{
	Window swwin = wSwitchPanelGetWindow(swpanel);

	if (wwin->flags.mapped || wwin->flags.shaded) {
		if (swwin != None) {
			Window win[2];

			win[0] = swwin;
			win[1] = wwin->frame->core->window;

			XRestackWindows(dpy, win, 2);
		} else
			XRaiseWindow(dpy, wwin->frame->core->window);
	}
}

static WWindow *change_focus_and_raise(WWindow *newFocused, WWindow *oldFocused,
				       WSwitchPanel *swpanel, WScreen *scr, Bool esc_cancel)
{
	if (!newFocused)
		return oldFocused;

	wWindowFocus(newFocused, oldFocused);
	oldFocused = newFocused;

	if (wPreferences.circ_raise) {
		CommitStacking(scr);

		if (!esc_cancel)
			raiseWindow(swpanel, newFocused);
	}

	return oldFocused;
}

void StartWindozeCycle(WWindow *wwin, XEvent *event, Bool next, Bool class_only)
{

	WShortKey binding;
	WSwitchPanel    *swpanel       = NULL;
	WScreen         *scr           = wScreenForRootWindow(event->xkey.root);
	KeyCode         leftKey        = XKeysymToKeycode(dpy, XK_Left);
	KeyCode         rightKey       = XKeysymToKeycode(dpy, XK_Right);
	KeyCode         homeKey        = XKeysymToKeycode(dpy, XK_Home);
	KeyCode         endKey         = XKeysymToKeycode(dpy, XK_End);
	KeyCode         shiftLKey      = XKeysymToKeycode(dpy, XK_Shift_L);
	KeyCode         shiftRKey      = XKeysymToKeycode(dpy, XK_Shift_R);
	KeyCode         escapeKey      = XKeysymToKeycode(dpy, XK_Escape);
	KeyCode         returnKey      = XKeysymToKeycode(dpy, XK_Return);
	Bool            esc_cancel     = False;
	Bool            somethingElse  = False;
	Bool            done           = False;
	Bool            hasModifier;
	int             modifiers;
	WWindow         *newFocused;
	WWindow         *oldFocused;
	XEvent          ev;


	if (!wwin)
		return;

	if (next) {
		if (class_only)
			binding = wKeyBindings[WKBD_GROUPNEXT];
		else
			binding = wKeyBindings[WKBD_FOCUSNEXT];
	} else {
		if (class_only)
			binding = wKeyBindings[WKBD_GROUPPREV];
		else
			binding = wKeyBindings[WKBD_FOCUSPREV];
	}

	hasModifier = (binding.modifier != 0);
	if (hasModifier)
		XGrabKeyboard(dpy, scr->root_win, False, GrabModeAsync, GrabModeAsync, CurrentTime);

	scr->flags.doing_alt_tab = 1;

	swpanel = wInitSwitchPanel(scr, wwin, class_only);
	oldFocused = wwin;

	if (swpanel) {
		if (wwin->flags.mapped && !wPreferences.panel_only_open) {
			if (wwin->client_flags.skip_switchpanel || wwin->client_flags.skip_window_list) {
				/* for GNUstep apps: main menu focus that is not in window focua list */
				wSwitchPanelSelectFirst(swpanel, False);
			}
			newFocused = wSwitchPanelSelectNext(swpanel, !next, True, class_only);
		}
		else {
			newFocused = wSwitchPanelSelectFirst(swpanel, False);
		}

		oldFocused = change_focus_and_raise(newFocused, oldFocused, swpanel, scr, False);
	} else {
		if (wwin->frame->workspace == scr->current_workspace)
			newFocused = wwin;
		else
			newFocused = NULL;
	}

	while (hasModifier && !done) {
		WMMaskEvent(dpy, KeyPressMask | KeyReleaseMask | ExposureMask
			    | PointerMotionMask | ButtonReleaseMask | EnterWindowMask, &ev);

		/* ignore CapsLock */
		modifiers = ev.xkey.state & w_global.shortcut.modifiers_mask;

		if (!swpanel)
			break;

		switch (ev.type) {
		case KeyPress:
			if ((wKeyBindings[WKBD_FOCUSNEXT].keycode == ev.xkey.keycode
			     && wKeyBindings[WKBD_FOCUSNEXT].modifier == modifiers)
			    || (wKeyBindings[WKBD_GROUPNEXT].keycode == ev.xkey.keycode
			    && wKeyBindings[WKBD_GROUPNEXT].modifier == modifiers)
			    || ev.xkey.keycode == rightKey) {

				newFocused = wSwitchPanelSelectNext(swpanel, False, ev.xkey.keycode != rightKey, (!class_only && wKeyBindings[WKBD_GROUPNEXT].keycode == ev.xkey.keycode && wKeyBindings[WKBD_GROUPNEXT].modifier == modifiers));
				oldFocused = change_focus_and_raise(newFocused, oldFocused, swpanel, scr, False);

			} else if ((wKeyBindings[WKBD_FOCUSPREV].keycode == ev.xkey.keycode
				    && wKeyBindings[WKBD_FOCUSPREV].modifier == modifiers)
			    || (wKeyBindings[WKBD_GROUPPREV].keycode == ev.xkey.keycode
			    && wKeyBindings[WKBD_GROUPPREV].modifier == modifiers)
				   || ev.xkey.keycode == leftKey) {

				newFocused = wSwitchPanelSelectNext(swpanel, True, ev.xkey.keycode != leftKey, (!class_only && wKeyBindings[WKBD_GROUPPREV].keycode == ev.xkey.keycode && wKeyBindings[WKBD_GROUPPREV].modifier == modifiers));
				oldFocused = change_focus_and_raise(newFocused, oldFocused, swpanel, scr, False);

			} else if (ev.xkey.keycode == homeKey || ev.xkey.keycode == endKey) {

				newFocused = wSwitchPanelSelectFirst(swpanel, ev.xkey.keycode != homeKey);
				oldFocused = change_focus_and_raise(newFocused, oldFocused, swpanel, scr, False);

			} else if (ev.xkey.keycode == escapeKey) {

				/* Focus the first window of the swpanel, despite the 'False' */
				newFocused = wSwitchPanelSelectFirst(swpanel, False);
				oldFocused = change_focus_and_raise(newFocused, oldFocused, swpanel, scr, True);
				esc_cancel = True;
				done = True;

			} else if (ev.xkey.keycode == returnKey) {

				/* Close the switch panel without eating the keypress */
				done = True;

			} else if (ev.xkey.keycode != shiftLKey && ev.xkey.keycode != shiftRKey) {

				somethingElse = True;
				done = True;
			}
			break;

		case KeyRelease:
			if (ev.xkey.keycode == shiftLKey || ev.xkey.keycode == shiftRKey)
				if (wPreferences.strict_windoze_cycle)
					break;

			if (ev.xkey.keycode == leftKey || ev.xkey.keycode == rightKey)
				break;

			if (ev.xkey.keycode == XK_Return)
				break;

			if (ev.xkey.keycode != binding.keycode)
				done = True;

			break;

		case EnterNotify:

			/* ignore unwanted EnterNotify's */
			break;

		case LeaveNotify:
		case MotionNotify:

		case ButtonRelease:
			{
				WWindow *tmp;
				tmp = wSwitchPanelHandleEvent(swpanel, &ev);
				if (tmp) {
					newFocused = tmp;
					oldFocused = change_focus_and_raise(newFocused, oldFocused, swpanel, scr, False);

					if (ev.type == ButtonRelease)
						done = True;
				}
			}
			break;

		default:
			WMHandleEvent(&ev);
			break;
		}
	}

	if (hasModifier)
		XUngrabKeyboard(dpy, CurrentTime);

	if (swpanel)
		wSwitchPanelDestroy(swpanel);

	if (newFocused && !esc_cancel) {
		wRaiseFrame(newFocused->frame->core);
		CommitStacking(scr);
		if (!newFocused->flags.mapped)
			wMakeWindowVisible(newFocused);
		wSetFocusTo(scr, newFocused);
	}

	scr->flags.doing_alt_tab = 0;

	if (somethingElse)
		WMHandleEvent(&ev);
}
