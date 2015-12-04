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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */

#include "wconfig.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

#include "WindowMaker.h"
#include "GNUstep.h"
#include "screen.h"
#include "wcore.h"
#include "window.h"
#include "framewin.h"
#include "keybind.h"
#include "actions.h"
#include "stacking.h"
#include "funcs.h"
#include "xinerama.h"
#include "switchpanel.h"

/* Globals */
extern WPreferences wPreferences;

extern WShortKey wKeyBindings[WKBD_LAST];


static void raiseWindow(WSwitchPanel *swpanel, WWindow *wwin)
{
    Window swwin= wSwitchPanelGetWindow(swpanel);
    
    if (wwin->flags.mapped) {
        if (swwin!=None) {
            Window win[2];
    
            win[0]= swwin;
            win[1]= wwin->frame->core->window;
    
            XRestackWindows(dpy, win, 2);
        } else
            XRaiseWindow(dpy, wwin->frame->core->window);
    }
}



void
StartWindozeCycle(WWindow *wwin, XEvent *event, Bool next)
{
    WScreen *scr = wScreenForRootWindow(event->xkey.root);
    Bool done = False;
    WWindow *newFocused;
    WWindow *oldFocused;
    int modifiers;
    XModifierKeymap *keymap = NULL;
    Bool hasModifier;
    Bool somethingElse = False;
    XEvent ev;
    WSwitchPanel *swpanel = NULL;
    KeyCode leftKey, rightKey, homeKey, endKey, shiftLKey, shiftRKey;

    if (!wwin)
        return;
  
    leftKey = XKeysymToKeycode(dpy, XK_Left);
    rightKey = XKeysymToKeycode(dpy, XK_Right);
    homeKey = XKeysymToKeycode(dpy, XK_Home);
    endKey = XKeysymToKeycode(dpy, XK_End);
    shiftLKey = XKeysymToKeycode(dpy, XK_Shift_L);
    shiftRKey = XKeysymToKeycode(dpy, XK_Shift_R);

    if (next)
        hasModifier = (wKeyBindings[WKBD_FOCUSNEXT].modifier != 0);
    else
        hasModifier = (wKeyBindings[WKBD_FOCUSPREV].modifier != 0);

    if (hasModifier) {
        keymap = XGetModifierMapping(dpy);

#ifdef DEBUG
        printf("Grabbing keyboard\n");
#endif
        XGrabKeyboard(dpy, scr->root_win, False, GrabModeAsync, GrabModeAsync,
                      CurrentTime);
    }

    scr->flags.doing_alt_tab = 1;

    swpanel =  wInitSwitchPanel(scr, wwin, scr->current_workspace);
    oldFocused = wwin;
  
    if (swpanel) {
        newFocused = wSwitchPanelSelectNext(swpanel, !next);
        if (newFocused) {
            wWindowFocus(newFocused, oldFocused);
            oldFocused = newFocused;

            if (wPreferences.circ_raise)
              raiseWindow(swpanel, newFocused);
        }
    }
    else
    {
        if (wwin->frame->workspace == scr->current_workspace)
            newFocused= wwin;
        else
            newFocused= NULL;
    }

    while (hasModifier && !done) {
        int i;

        WMMaskEvent(dpy, KeyPressMask|KeyReleaseMask|ExposureMask
                    |PointerMotionMask|ButtonReleaseMask, &ev);

        /* ignore CapsLock */
        modifiers = ev.xkey.state & ValidModMask;

        switch (ev.type) {
        case KeyPress:
#ifdef DEBUG
            printf("Got key press\n");
#endif
            if ((wKeyBindings[WKBD_FOCUSNEXT].keycode == ev.xkey.keycode
                 && wKeyBindings[WKBD_FOCUSNEXT].modifier == modifiers)
                || ev.xkey.keycode == rightKey) {

                if (swpanel) {
                    newFocused = wSwitchPanelSelectNext(swpanel, False);
                    if (newFocused) {
                        wWindowFocus(newFocused, oldFocused);
                        oldFocused = newFocused;
                      
                        if (wPreferences.circ_raise) {
                            CommitStacking(scr);
                            raiseWindow(swpanel, newFocused);
                        }
                    }
                }
            } else if ((wKeyBindings[WKBD_FOCUSPREV].keycode == ev.xkey.keycode
                        && wKeyBindings[WKBD_FOCUSPREV].modifier == modifiers)
                       || ev.xkey.keycode == leftKey) {

                if (swpanel) {
                    newFocused = wSwitchPanelSelectNext(swpanel, True);
                    if (newFocused) {
                        wWindowFocus(newFocused, oldFocused);
                        oldFocused = newFocused;
                        
                        if (wPreferences.circ_raise) {
                            CommitStacking(scr);
                            raiseWindow(swpanel, newFocused);
                        }
                    }
                }
            } else if (ev.xkey.keycode == homeKey || ev.xkey.keycode == endKey) {
                if (swpanel) {
                    newFocused = wSwitchPanelSelectFirst(swpanel, ev.xkey.keycode != homeKey);
                    if (newFocused) {
                        wWindowFocus(newFocused, oldFocused);
                        oldFocused = newFocused;

                        if (wPreferences.circ_raise) {
                            CommitStacking(scr);
                            raiseWindow(swpanel, newFocused);
                        }
                    }
                }
            } else if (ev.xkey.keycode != shiftLKey && ev.xkey.keycode != shiftRKey) {
#ifdef DEBUG
                printf("Got something else\n");
#endif
                somethingElse = True;
                done = True;
            }
            break;
        case KeyRelease:
#ifdef DEBUG
            printf("Got key release\n");
#endif
            for (i = 0; i < 8 * keymap->max_keypermod; i++) {
                if (keymap->modifiermap[i] == ev.xkey.keycode &&
                    wKeyBindings[WKBD_FOCUSNEXT].modifier
                    & 1<<(i/keymap->max_keypermod)) {
                    done = True;
                    break;
                }
            }
            break;
         
        case LeaveNotify:
        case MotionNotify:
        case ButtonRelease:
            {
                WWindow *tmp;
                if (swpanel) {
                    tmp = wSwitchPanelHandleEvent(swpanel, &ev);
                    if (tmp) {
                        newFocused = tmp;
                        wWindowFocus(newFocused, oldFocused);
                        oldFocused = newFocused;
                        
                        if (wPreferences.circ_raise) {
                            CommitStacking(scr);
                            raiseWindow(swpanel, newFocused);
                        }
                        
                        if (ev.type == ButtonRelease)
                          done= True;
                    }
                }
            }
            break;

        default:
            WMHandleEvent(&ev);
            break;
        }
    }
    if (keymap)
        XFreeModifiermap(keymap);

    if (hasModifier) {
#ifdef DEBUG
        printf("Ungrabbing keyboard\n");
#endif
        XUngrabKeyboard(dpy, CurrentTime);
    }

    if (swpanel)
        wSwitchPanelDestroy(swpanel);

    if (newFocused) {
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


