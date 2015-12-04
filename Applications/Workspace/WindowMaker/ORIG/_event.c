/* event.c- event loop and handling
 *
 *  Window Maker window manager
 *
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */


#include "wconfig.h"


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>



#include <X11/Xlib.h>
#include <X11/Xutil.h>
#ifdef SHAPE
# include <X11/extensions/shape.h>
#endif
#ifdef XDND
#include "xdnd.h"
#endif

#ifdef KEEP_XKB_LOCK_STATUS
#include <X11/XKBlib.h>
#endif /* KEEP_XKB_LOCK_STATUS */

#include "WindowMaker.h"
#include "window.h"
#include "actions.h"
#include "client.h"
#include "funcs.h"
#include "keybind.h"
#include "application.h"
#include "stacking.h"
#include "defaults.h"
#include "workspace.h"
#include "dock.h"
#include "framewin.h"
#include "properties.h"
#include "balloon.h"
#include "xinerama.h"

#ifdef NETWM_HINTS
# include "wmspec.h"
#endif

/******** Global Variables **********/
extern XContext wWinContext;
extern XContext wVEdgeContext;

extern Cursor wCursor[WCUR_LAST];

extern WShortKey wKeyBindings[WKBD_LAST];
extern int wScreenCount;
extern Time LastTimestamp;
extern Time LastFocusChange;

extern WPreferences wPreferences;

#define MOD_MASK wPreferences.modifier_mask

extern Atom _XA_WM_COLORMAP_NOTIFY;

extern Atom _XA_WM_CHANGE_STATE;
extern Atom _XA_WM_DELETE_WINDOW;
extern Atom _XA_GNUSTEP_WM_ATTR;
extern Atom _XA_GNUSTEP_WM_MINIATURIZE_WINDOW;
extern Atom _XA_GNUSTEP_TITLEBAR_STATE;
extern Atom _XA_WINDOWMAKER_WM_FUNCTION;
extern Atom _XA_WINDOWMAKER_COMMAND;


#ifdef SHAPE
extern Bool wShapeSupported;
extern int wShapeEventBase;
#endif

#ifdef KEEP_XKB_LOCK_STATUS
extern int wXkbEventBase;
#endif

/* special flags */
extern char WDelayedActionSet;


/************ Local stuff ***********/


static void saveTimestamp(XEvent *event);
static void handleColormapNotify();
static void handleMapNotify();
static void handleUnmapNotify();
static void handleButtonPress();
static void handleExpose();
static void handleDestroyNotify();
static void handleConfigureRequest();
static void handleMapRequest();
static void handlePropertyNotify();
static void handleEnterNotify();
static void handleLeaveNotify();
static void handleExtensions();
static void handleClientMessage();
static void handleKeyPress();
static void handleFocusIn();
static void handleMotionNotify();
static void handleVisibilityNotify();


#ifdef SHAPE
static void handleShapeNotify();
#endif

/* called from the signal handler */
void NotifyDeadProcess(pid_t pid, unsigned char status);

/* real dead process handler */
static void handleDeadProcess(void *foo);


typedef struct DeadProcesses {
    pid_t 		pid;
    unsigned char 	exit_status;
} DeadProcesses;

/* stack of dead processes */
static DeadProcesses deadProcesses[MAX_DEAD_PROCESSES];
static int deadProcessPtr=0;


typedef struct DeathHandler {
    WDeathHandler	*callback;
    pid_t 		pid;
    void 		*client_data;
} DeathHandler;

static WMArray *deathHandlers=NULL;



WMagicNumber
wAddDeathHandler(pid_t pid, WDeathHandler *callback, void *cdata)
{
    DeathHandler *handler;

    handler = malloc(sizeof(DeathHandler));
    if (!handler)
        return 0;

    handler->pid = pid;
    handler->callback = callback;
    handler->client_data = cdata;

    if (!deathHandlers)
        deathHandlers = WMCreateArrayWithDestructor(8, wfree);

    WMAddToArray(deathHandlers, handler);

    return handler;
}



void
wDeleteDeathHandler(WMagicNumber id)
{
    DeathHandler *handler=(DeathHandler*)id;

    if (!handler || !deathHandlers)
        return;

    /* array destructor will call wfree(handler) */
    WMRemoveFromArray(deathHandlers, handler);
}


void
DispatchEvent(XEvent *event)
{
    if (deathHandlers)
        handleDeadProcess(NULL);

    if (WCHECK_STATE(WSTATE_NEED_EXIT)) {
        WCHANGE_STATE(WSTATE_EXITING);
        /* received SIGTERM */
        /*
         * WMHandleEvent() can't be called from anything
         * executed inside here, or we can get in a infinite
         * recursive loop.
         */
        Shutdown(WSExitMode);

    } else if (WCHECK_STATE(WSTATE_NEED_RESTART)) {
        WCHANGE_STATE(WSTATE_RESTARTING);

        Shutdown(WSRestartPreparationMode);
        /* received SIGHUP */
        Restart(NULL, True);
    } else if (WCHECK_STATE(WSTATE_NEED_REREAD)) {
        WCHANGE_STATE(WSTATE_NORMAL);
        wDefaultsCheckDomains("bla");
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
        if (event->xmapping.request == MappingKeyboard
            || event->xmapping.request == MappingModifier)
            XRefreshKeyboardMapping(&event->xmapping);
        break;

    case FocusIn:
        handleFocusIn(event);
        break;

    case VisibilityNotify:
        handleVisibilityNotify(event);
        break;
    default:
        handleExtensions(event);
        break;
    }
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
 *----------------------------------------------------------------------
 */
void
EventLoop()
{
    XEvent event;

    for(;;) {
        WMNextEvent(dpy, &event);
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
void
ProcessPendingEvents()
{
    XEvent event;
    int count;

    XSync(dpy, False);

    /* Take a snapshot of the event count in the queue */
    count = XPending(dpy);

    while (count>0 && XPending(dpy)) {
        WMNextEvent(dpy, &event);
        WMHandleEvent(&event);
        count--;
    }
}


Bool
IsDoubleClick(WScreen *scr, XEvent *event)
{
    if ((scr->last_click_time>0) &&
        (event->xbutton.time-scr->last_click_time<=wPreferences.dblclick_time)
        && (event->xbutton.button == scr->last_click_button)
        && (event->xbutton.window == scr->last_click_window)) {

        scr->flags.next_click_is_not_double = 1;
        scr->last_click_time = 0;
        scr->last_click_window = event->xbutton.window;

        return True;
    }
    return False;
}


void
NotifyDeadProcess(pid_t pid, unsigned char status)
{
    if (deadProcessPtr>=MAX_DEAD_PROCESSES-1) {
        wwarning("stack overflow: too many dead processes");
        return;
    }
    /* stack the process to be handled later,
     * as this is called from the signal handler */
    deadProcesses[deadProcessPtr].pid = pid;
    deadProcesses[deadProcessPtr].exit_status = status;
    deadProcessPtr++;
}


static void
handleDeadProcess(void *foo)
{
    DeathHandler *tmp;
    int i;

    for (i=0; i<deadProcessPtr; i++) {
        wWindowDeleteSavedStatesForPID(deadProcesses[i].pid);
    }

    if (!deathHandlers) {
        deadProcessPtr=0;
        return;
    }

    /* get the pids on the queue and call handlers */
    while (deadProcessPtr>0) {
        deadProcessPtr--;

        for (i = WMGetArrayItemCount(deathHandlers)-1; i >= 0; i--) {
            tmp = WMGetFromArray(deathHandlers, i);
            if (!tmp)
                continue;

            if (tmp->pid == deadProcesses[deadProcessPtr].pid) {
                (*tmp->callback)(tmp->pid,
                                 deadProcesses[deadProcessPtr].exit_status,
                                 tmp->client_data);
                wDeleteDeathHandler(tmp);
            }
        }
    }
}


static void
saveTimestamp(XEvent *event)
{
    /*
     * Never save CurrentTime as LastTimestamp because CurrentTime
     * it's not a real timestamp (it's the 0L constant)
     */

    switch (event->type) {
    case ButtonRelease:
    case ButtonPress:
        LastTimestamp = event->xbutton.time;
        break;
    case KeyPress:
    case KeyRelease:
        LastTimestamp = event->xkey.time;
        break;
    case MotionNotify:
        LastTimestamp = event->xmotion.time;
        break;
    case PropertyNotify:
        LastTimestamp = event->xproperty.time;
        break;
    case EnterNotify:
    case LeaveNotify:
        LastTimestamp = event->xcrossing.time;
        break;
    case SelectionClear:
        LastTimestamp = event->xselectionclear.time;
        break;
    case SelectionRequest:
        LastTimestamp = event->xselectionrequest.time;
        break;
    case SelectionNotify:
        LastTimestamp = event->xselection.time;
#ifdef XDND
        wXDNDProcessSelection(event);
#endif
        break;
    }
}


static int
matchWindow(void *item, void *cdata)
{
    return (((WFakeGroupLeader*)item)->origLeader == (Window)cdata);
}


static void
handleExtensions(XEvent *event)
{
#ifdef KEEP_XKB_LOCK_STATUS
    XkbEvent *xkbevent;
    xkbevent = (XkbEvent *)event;
#endif /*KEEP_XKB_LOCK_STATUS*/
#ifdef SHAPE
    if (wShapeSupported && event->type == (wShapeEventBase+ShapeNotify)) {
        handleShapeNotify(event);
    }
#endif
#ifdef KEEP_XKB_LOCK_STATUS
    if (wPreferences.modelock && (xkbevent->type == wXkbEventBase)){
        handleXkbIndicatorStateNotify(event);
    }
#endif /*KEEP_XKB_LOCK_STATUS*/
}


static void
handleMapRequest(XEvent *ev)
{
    WWindow *wwin;
    WScreen *scr = NULL;
    Window window = ev->xmaprequest.window;

#ifdef DEBUG
    printf("got map request for %x\n", (unsigned)window);
#endif
    fprintf(stderr, "got map request for %x\n", (unsigned)window);
    if ((wwin = wWindowFor(window))) {
        if (wwin->flags.shaded) {
            wUnshadeWindow(wwin);
        }
        /* deiconify window */
        if (wwin->flags.miniaturized) {
            wDeiconifyWindow(wwin);
        } else if (wwin->flags.hidden) {
            WApplication *wapp = wApplicationOf(wwin->main_window);
            /* go to the last workspace that the user worked on the app */
            if (wapp) {
                wWorkspaceChange(wwin->screen_ptr, wapp->last_workspace);
            }
            wUnhideApplication(wapp, False, False);
        }
        return;
    }

    scr = wScreenForRootWindow(ev->xmaprequest.parent);

    wwin = wManageWindow(scr, window);

    /*
     * This is to let the Dock know that the application it launched
     * has already been mapped (eg: it has finished launching).
     * It is not necessary for normally docked apps, but is needed for
     * apps that were forcedly docked (like with dockit).
     */
    if (scr->last_dock) {
        if (wwin && wwin->main_window!=None && wwin->main_window!=window)
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
                wHideApplication(wapp);
            }
        }
    }
}


static void
handleDestroyNotify(XEvent *event)
{
    WWindow *wwin;
    WApplication *app;
    Window window = event->xdestroywindow.window;
    WScreen *scr = wScreenForRootWindow(event->xdestroywindow.event);
    int index;

#ifdef DEBUG
    printf("got destroy notify\n");
#endif
    wwin = wWindowFor(window);
    if (wwin) {
        wUnmanageWindow(wwin, False, True);
    }

    if (scr != NULL) {
        while ((index = WMFindInArray(scr->fakeGroupLeaders, matchWindow,
                                      (void*)window)) != WANotFound) {
            WFakeGroupLeader *fPtr;

            fPtr = WMGetFromArray(scr->fakeGroupLeaders, index);
            if (fPtr->retainCount > 0) {
                fPtr->retainCount--;
                if (fPtr->retainCount==0 && fPtr->leader!=None) {
                    XDestroyWindow(dpy, fPtr->leader);
                    fPtr->leader = None;
                    XFlush(dpy);
                }
            }
            fPtr->origLeader = None;
        }
    }

    app = wApplicationOf(window);
    if (app) {
        if (window == app->main_window) {
            app->refcount = 0;
            wwin = app->main_window_desc->screen_ptr->focused_window;
            while (wwin) {
                if (wwin->main_window == window) {
                    wwin->main_window = None;
                }
                wwin = wwin->prev;
            }
        }
        wApplicationDestroy(app);
    }
}



static void
handleExpose(XEvent *event)
{
    WObjDescriptor *desc;
    XEvent ev;

#ifdef DEBUG
    printf("got expose\n");
#endif
    while (XCheckTypedWindowEvent(dpy, event->xexpose.window, Expose, &ev));

    if (XFindContext(dpy, event->xexpose.window, wWinContext,
                     (XPointer *)&desc)==XCNOENT) {
        return;
    }

    if (desc->handle_expose) {
        (*desc->handle_expose)(desc, event);
    }
}

static void
executeButtonAction(WScreen *scr, XEvent *event, int action)
{
    switch(action) {
    case WA_SELECT_WINDOWS:
        wUnselectWindows(scr);
        wSelectWindows(scr, event);
        break;
    case WA_OPEN_APPMENU:
        OpenRootMenu(scr, event->xbutton.x_root, event->xbutton.y_root, False);
        /* ugly hack */
        if (scr->root_menu) {
            if (scr->root_menu->brother->flags.mapped)
                event->xbutton.window = scr->root_menu->brother->frame->core->window;
            else
                event->xbutton.window = scr->root_menu->frame->core->window;
        }
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
    default:
        break;
    }
}


/* bindable */
static void
handleButtonPress(XEvent *event)
{
    WObjDescriptor *desc;
    WScreen *scr;

#ifdef DEBUG
    printf("got button press\n");
#endif
    scr = wScreenForRootWindow(event->xbutton.root);

#ifdef BALLOON_TEXT
    wBalloonHide(scr);
#endif


#ifndef LITE
    if (event->xbutton.window==scr->root_win) {
        if (event->xbutton.button==Button1 &&
            wPreferences.mouse_button1!=WA_NONE) {
            executeButtonAction(scr, event, wPreferences.mouse_button1);
        } else if (event->xbutton.button==Button2 &&
                   wPreferences.mouse_button2!=WA_NONE) {
            executeButtonAction(scr, event, wPreferences.mouse_button2);
        } else if (event->xbutton.button==Button3 &&
                   wPreferences.mouse_button3!=WA_NONE) {
            executeButtonAction(scr, event, wPreferences.mouse_button3);
        } else if (event->xbutton.button==Button4 &&
                   wPreferences.mouse_wheel!=WA_NONE) {
            wWorkspaceRelativeChange(scr, 1);
        } else if (event->xbutton.button==Button5 &&
                   wPreferences.mouse_wheel!=WA_NONE) {
            wWorkspaceRelativeChange(scr, -1);
        }
    }
#endif /* !LITE */

    desc = NULL;
    if (XFindContext(dpy, event->xbutton.subwindow, wWinContext,
                     (XPointer *)&desc)==XCNOENT) {
        if (XFindContext(dpy, event->xbutton.window, wWinContext,
                         (XPointer *)&desc)==XCNOENT) {
            return;
        }
    }

    if (desc->parent_type == WCLASS_WINDOW) {
        XSync(dpy, 0);

        if (event->xbutton.state & MOD_MASK) {
            XAllowEvents(dpy, AsyncPointer, CurrentTime);
        }

        /*	if (wPreferences.focus_mode == WKF_CLICK) {*/
        if (wPreferences.ignore_focus_click) {
            XAllowEvents(dpy, AsyncPointer, CurrentTime);
        }
        XAllowEvents(dpy, ReplayPointer, CurrentTime);
        /*	}*/
        XSync(dpy, 0);
    } else if (desc->parent_type == WCLASS_APPICON
               || desc->parent_type == WCLASS_MINIWINDOW
               || desc->parent_type == WCLASS_DOCK_ICON) {
        if (event->xbutton.state & MOD_MASK) {
            XSync(dpy, 0);
            XAllowEvents(dpy, AsyncPointer, CurrentTime);
            XSync(dpy, 0);
        }
    }

    if (desc->handle_mousedown!=NULL) {
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


static void
handleMapNotify(XEvent *event)
{
    WWindow *wwin;
#ifdef DEBUG
    printf("got map\n");
#endif
    fprintf(stderr, "got map\n");
    wwin = wWindowFor(event->xmap.event);
    if (wwin && wwin->client_win == event->xmap.event) {
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


static void
handleUnmapNotify(XEvent *event)
{
    WWindow *wwin;
    XEvent ev;
    Bool withdraw = False;
#ifdef DEBUG
    printf("got unmap\n");
#endif
    /* only process windows with StructureNotify selected
     * (ignore SubstructureNotify) */
    wwin = wWindowFor(event->xunmap.window);
    if (!wwin)
        return;

    /* whether the event is a Withdrawal request */
    if (event->xunmap.event == wwin->screen_ptr->root_win
        && event->xunmap.send_event)
        withdraw = True;

    if (wwin->client_win != event->xunmap.event && !withdraw)
        return;

    if (!wwin->flags.mapped && !withdraw
        && wwin->frame->workspace == wwin->screen_ptr->current_workspace
        && !wwin->flags.miniaturized && !wwin->flags.hidden)
        return;

    XGrabServer(dpy);
    XUnmapWindow(dpy, wwin->frame->core->window);
    wwin->flags.mapped = 0;
    XSync(dpy, 0);
    /* check if the window was destroyed */
    if (XCheckTypedWindowEvent(dpy, wwin->client_win, DestroyNotify,&ev)) {
        DispatchEvent(&ev);
    } else {
        Bool reparented = False;

        if (XCheckTypedWindowEvent(dpy, wwin->client_win, ReparentNotify, &ev))
            reparented = True;

        /* withdraw window */
        wwin->flags.mapped = 0;
        if (!reparented)
            wClientSetState(wwin, WithdrawnState, None);

        /* if the window was reparented, do not reparent it back to the
         * root window */
        wUnmanageWindow(wwin, !reparented, False);
    }
    XUngrabServer(dpy);
}


static void
handleConfigureRequest(XEvent *event)
{
    WWindow *wwin;
#ifdef DEBUG
    printf("got configure request\n");
#endif
    if (!(wwin=wWindowFor(event->xconfigurerequest.window))) {
        /*
         * Configure request for unmapped window
         */
        wClientConfigure(NULL, &(event->xconfigurerequest));
    } else {
        wClientConfigure(wwin, &(event->xconfigurerequest));
    }
}


static void
handlePropertyNotify(XEvent *event)
{
    WWindow *wwin;
    WApplication *wapp;
    Window jr;
    int ji;
    unsigned int ju;
    WScreen *scr;
#ifdef DEBUG
    printf("got property notify\n");
#endif
    if ((wwin=wWindowFor(event->xproperty.window))) {
        if (!XGetGeometry(dpy, wwin->client_win, &jr, &ji, &ji,
                          &ju, &ju, &ju, &ju)) {
            return;
        }
        wClientCheckProperty(wwin, &event->xproperty);
    }
    wapp = wApplicationOf(event->xproperty.window);
    if (wapp) {
        wClientCheckProperty(wapp->main_window_desc, &event->xproperty);
    }

    scr = wScreenForWindow(event->xproperty.window);
}


static void
handleClientMessage(XEvent *event)
{
    WWindow *wwin;
    WObjDescriptor *desc;
#ifdef DEBUG
    printf("got client message\n");
#endif
    /* handle transition from Normal to Iconic state */
    if (event->xclient.message_type == _XA_WM_CHANGE_STATE
        && event->xclient.format == 32
        && event->xclient.data.l[0] == IconicState) {

        wwin = wWindowFor(event->xclient.window);
        if (!wwin) return;
        if (!wwin->flags.miniaturized)
            wIconifyWindow(wwin);
    } else if (event->xclient.message_type == _XA_WM_COLORMAP_NOTIFY
               && event->xclient.format == 32) {
        WScreen *scr = wScreenSearchForRootWindow(event->xclient.window);

        if (!scr)
            return;

        if (event->xclient.data.l[1] == 1) {   /* starting */
            wColormapAllowClientInstallation(scr, True);
        } else {		       /* stopping */
            wColormapAllowClientInstallation(scr, False);
        }
    } else if (event->xclient.message_type == _XA_WINDOWMAKER_COMMAND) {

        wDefaultsCheckDomains("bla");

    } else if (event->xclient.message_type == _XA_WINDOWMAKER_WM_FUNCTION) {
        WApplication *wapp;
        int done=0;
        wapp = wApplicationOf(event->xclient.window);
        if (wapp) {
            switch (event->xclient.data.l[0]) {
            case WMFHideOtherApplications:
                wHideOtherApplications(wapp->main_window_desc);
                done = 1;
                break;

            case WMFHideApplication:
                wHideApplication(wapp);
                done = 1;
                break;
            }
        }
        if (!done) {
            wwin = wWindowFor(event->xclient.window);
            if (wwin) {
                switch (event->xclient.data.l[0]) {
                case WMFHideOtherApplications:
                    wHideOtherApplications(wwin);
                    break;

                case WMFHideApplication:
                    wHideApplication(wApplicationOf(wwin->main_window));
                    break;
                }
            }
        }
    } else if (event->xclient.message_type == _XA_GNUSTEP_WM_ATTR) {
        wwin = wWindowFor(event->xclient.window);
        if (!wwin) return;
        switch (event->xclient.data.l[0]) {
        case GSWindowLevelAttr:
            {
                int level = (int)event->xclient.data.l[1];

                if (WINDOW_LEVEL(wwin) != level) {
                    ChangeStackingLevel(wwin->frame->core, level);
                }
            }
            break;
        }
    } else if (event->xclient.message_type == _XA_GNUSTEP_TITLEBAR_STATE) {
        wwin = wWindowFor(event->xclient.window);
        if (!wwin) return;
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
#ifdef NETWM_HINTS
    } else if (wNETWMProcessClientMessage(&event->xclient)) {
        /* do nothing */
#endif
#ifdef XDND
    } else if (wXDNDProcessClientMessage(&event->xclient)) {
        /* do nothing */
#endif /* XDND */
    } else {
        /*
         * Non-standard thing, but needed by OffiX DND.
         * For when the icon frame gets a ClientMessage
         * that should have gone to the icon_window.
         */
        if (XFindContext(dpy, event->xbutton.window, wWinContext,
                         (XPointer *)&desc)!=XCNOENT) {
            struct WIcon *icon=NULL;

            if (desc->parent_type == WCLASS_MINIWINDOW) {
                icon = (WIcon*)desc->parent;
            } else if (desc->parent_type == WCLASS_DOCK_ICON
                       || desc->parent_type == WCLASS_APPICON) {
                icon = ((WAppIcon*)desc->parent)->icon;
            }
            if (icon && (wwin=icon->owner)) {
                if (wwin->client_win!=event->xclient.window) {
                    event->xclient.window = wwin->client_win;
                    XSendEvent(dpy, wwin->client_win, False, NoEventMask,
                               event);
                }
            }
        }
    }
}


static void
raiseWindow(WScreen *scr)
{
    WWindow *wwin;

    scr->autoRaiseTimer = NULL;

    wwin = wWindowFor(scr->autoRaiseWindow);
    if (!wwin)
        return;

    if (!wwin->flags.destroyed && wwin->flags.focused) {
        wRaiseFrame(wwin->frame->core);
        /* this is needed or a race condition will occur */
        XSync(dpy, False);
    }
}


static void
handleEnterNotify(XEvent *event)
{
    WWindow *wwin;
    WObjDescriptor *desc = NULL;
#ifdef VIRTUAL_DESKTOP
    void (*vdHandler)(XEvent * event);
#endif
    XEvent ev;
    WScreen *scr = wScreenForRootWindow(event->xcrossing.root);
#ifdef DEBUG
    printf("got enter notify\n");
#endif

#ifdef VIRTUAL_DESKTOP
    if (XFindContext(dpy, event->xcrossing.window, wVEdgeContext,
                     (XPointer *)&vdHandler)!=XCNOENT) {
        (*vdHandler)(event);
    }
#endif

    if (XCheckTypedWindowEvent(dpy, event->xcrossing.window, LeaveNotify,
                               &ev)) {
        /* already left the window... */
        saveTimestamp(&ev);
        if (ev.xcrossing.mode==event->xcrossing.mode
            && ev.xcrossing.detail==event->xcrossing.detail) {
            return;
        }
    }

    if (XFindContext(dpy, event->xcrossing.window, wWinContext,
                     (XPointer *)&desc)!=XCNOENT) {
        if(desc->handle_enternotify)
            (*desc->handle_enternotify)(desc, event);
    }

    /* enter to window */
    wwin = wWindowFor(event->xcrossing.window);
    if (!wwin) {
        if (wPreferences.colormap_mode==WCM_POINTER) {
            wColormapInstallForWindow(scr, NULL);
        }
        if (scr->autoRaiseTimer
            && event->xcrossing.root==event->xcrossing.window) {
            WMDeleteTimerHandler(scr->autoRaiseTimer);
            scr->autoRaiseTimer = NULL;
        }
    } else {
        /* set auto raise timer even if in focus-follows-mouse mode
         * and the event is for the frame window, even if the window
         * has focus already.  useful if you move the pointer from a focused
         * window to the root window and back pretty fast
         *
         * set focus if in focus-follows-mouse mode and the event
         * is for the frame window and window doesn't have focus yet */
        if (wPreferences.focus_mode==WKF_SLOPPY
            && wwin->frame->core->window==event->xcrossing.window
            && !scr->flags.doing_alt_tab) {

            if (!wwin->flags.focused && !WFLAGP(wwin, no_focusable))
                wSetFocusTo(scr, wwin);

            if (scr->autoRaiseTimer)
                WMDeleteTimerHandler(scr->autoRaiseTimer);
            scr->autoRaiseTimer = NULL;

            if (wPreferences.raise_delay && !WFLAGP(wwin, no_focusable)) {
                scr->autoRaiseWindow = wwin->frame->core->window;
                scr->autoRaiseTimer
                    = WMAddTimerHandler(wPreferences.raise_delay,
                                        (WMCallback*)raiseWindow, scr);
            }
        }
        /* Install colormap for window, if the colormap installation mode
         * is colormap_follows_mouse */
        if (wPreferences.colormap_mode==WCM_POINTER) {
            if (wwin->client_win==event->xcrossing.window)
                wColormapInstallForWindow(scr, wwin);
            else
                wColormapInstallForWindow(scr, NULL);
        }
    }

    /* a little kluge to hide the clip balloon */
    if (!wPreferences.flags.noclip && scr->flags.clip_balloon_mapped) {
        if (!desc) {
            XUnmapWindow(dpy, scr->clip_balloon);
            scr->flags.clip_balloon_mapped = 0;
        } else {
            if (desc->parent_type!=WCLASS_DOCK_ICON
                || scr->clip_icon != desc->parent) {
                XUnmapWindow(dpy, scr->clip_balloon);
                scr->flags.clip_balloon_mapped = 0;
            }
        }
    }

    if (event->xcrossing.window == event->xcrossing.root
        && event->xcrossing.detail == NotifyNormal
        && event->xcrossing.detail != NotifyInferior
        && wPreferences.focus_mode != WKF_CLICK) {

        wSetFocusTo(scr, scr->focused_window);
    }

#ifdef BALLOON_TEXT
    wBalloonEnteredObject(scr, desc);
#endif
}


static void
handleLeaveNotify(XEvent *event)
{
    WObjDescriptor *desc = NULL;

    if (XFindContext(dpy, event->xcrossing.window, wWinContext,
                     (XPointer *)&desc)!=XCNOENT) {
        if(desc->handle_leavenotify)
            (*desc->handle_leavenotify)(desc, event);
    }
}


#ifdef SHAPE
static void
handleShapeNotify(XEvent *event)
{
    XShapeEvent *shev = (XShapeEvent*)event;
    WWindow *wwin;
    XEvent ev;
#ifdef DEBUG
    printf("got shape notify\n");
#endif
    while (XCheckTypedWindowEvent(dpy, shev->window, event->type, &ev)) {
        XShapeEvent *sev = (XShapeEvent*)&ev;

        if (sev->kind == ShapeBounding) {
            if (sev->shaped == shev->shaped) {
                *shev = *sev;
            } else {
                XPutBackEvent(dpy, &ev);
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
#endif /* SHAPE */

#ifdef KEEP_XKB_LOCK_STATUS
/* please help ]d if you know what to do */
handleXkbIndicatorStateNotify(XEvent *event)
{
    WWindow *wwin;
    WScreen *scr;
    XkbStateRec staterec;
    int i;

    for (i=0; i<wScreenCount; i++) {
        scr = wScreenWithNumber(i);
        wwin = scr->focused_window;
        if (wwin && wwin->flags.focused) {
            XkbGetState(dpy,XkbUseCoreKbd,&staterec);
            if (wwin->frame->languagemode != staterec.group) {
                wwin->frame->last_languagemode = wwin->frame->languagemode;
                wwin->frame->languagemode = staterec.group;
            }
#ifdef XKB_BUTTON_HINT
            if (wwin->frame->titlebar) {
                wFrameWindowPaint(wwin->frame);
            }
#endif
        }
    }
}
#endif /*KEEP_XKB_LOCK_STATUS*/

static void
handleColormapNotify(XEvent *event)
{
    WWindow *wwin;
    WScreen *scr;
    Bool reinstall = False;

    wwin = wWindowFor(event->xcolormap.window);
    if (!wwin)
        return;

    scr = wwin->screen_ptr;

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
    } while (XCheckTypedEvent(dpy, ColormapNotify, event)
             && ((wwin = wWindowFor(event->xcolormap.window)) || 1));

    if (reinstall && scr->current_colormap!=None) {
        if (!scr->flags.colormap_stuff_blocked)
            XInstallColormap(dpy, scr->current_colormap);
    }
}



static void
handleFocusIn(XEvent *event)
{
    WWindow *wwin;

    /*
     * For applications that like stealing the focus.
     */
    while (XCheckTypedEvent(dpy, FocusIn, event));
    saveTimestamp(event);
    if (event->xfocus.mode == NotifyUngrab
        || event->xfocus.mode == NotifyGrab
        || event->xfocus.detail > NotifyNonlinearVirtual) {
        return;
    }

    wwin = wWindowFor(event->xfocus.window);
    if (wwin && !wwin->flags.focused) {
        if (wwin->flags.mapped)
            wSetFocusTo(wwin->screen_ptr, wwin);
        else
            wSetFocusTo(wwin->screen_ptr, NULL);
    } else if (!wwin) {
        WScreen *scr = wScreenForWindow(event->xfocus.window);
        if (scr)
            wSetFocusTo(scr, NULL);
    }
}


static WWindow*
windowUnderPointer(WScreen *scr)
{
    unsigned int mask;
    int foo;
    Window bar, win;

    if (XQueryPointer(dpy, scr->root_win, &bar, &win, &foo, &foo, &foo, &foo,
                      &mask))
        return wWindowFor(win);
    return NULL;
}


static int CheckFullScreenWindowFocused(WScreen *scr)
{
  if (scr->focused_window && scr->focused_window->flags.fullscreen)
      return 1;
  else
      return 0;
}


static void
handleKeyPress(XEvent *event)
{
    WScreen *scr = wScreenForRootWindow(event->xkey.root);
    WWindow *wwin = scr->focused_window;
    int i;
    int modifiers;
    int command=-1, index;
#ifdef KEEP_XKB_LOCK_STATUS
    XkbStateRec staterec;
#endif /*KEEP_XKB_LOCK_STATUS*/

    /* ignore CapsLock */
    modifiers = event->xkey.state & ValidModMask;

    for (i=0; i<WKBD_LAST; i++) {
        if (wKeyBindings[i].keycode==0)
            continue;

        if (wKeyBindings[i].keycode==event->xkey.keycode
            && (/*wKeyBindings[i].modifier==0
            ||*/ wKeyBindings[i].modifier==modifiers)) {
            command = i;
            break;
        }
    }


    if (command < 0) {
#ifdef LITE
        {
#if 0
        }
#endif
#else
        if (!wRootMenuPerformShortcut(event)) {
#endif
            static int dontLoop = 0;

            if (dontLoop > 10) {
                wwarning("problem with key event processing code");
                return;
            }
            dontLoop++;
            /* if the focused window is an internal window, try redispatching
             * the event to the managed window, as it can be a WINGs window */
            if (wwin && wwin->flags.internal_window
                && wwin->client_leader!=None) {
                /* client_leader contains the WINGs toplevel */
                event->xany.window = wwin->client_leader;
                WMHandleEvent(event);
            }
            dontLoop--;
        }
        return;
    }

#define ISMAPPED(w) ((w) && !(w)->flags.miniaturized && ((w)->flags.mapped || (w)->flags.shaded))
#define ISFOCUSED(w) ((w) && (w)->flags.focused)

    switch (command) {
#ifndef LITE
    case WKBD_ROOTMENU:
        /*OpenRootMenu(scr, event->xkey.x_root, event->xkey.y_root, True);*/
        if (!CheckFullScreenWindowFocused(scr)) {
            WMRect rect = wGetRectForHead(scr, wGetHeadForPointerLocation(scr));
            OpenRootMenu(scr, rect.pos.x + rect.size.width/2, rect.pos.y + rect.size.height/2, True);
        }
        break;
    case WKBD_WINDOWLIST:
        if (!CheckFullScreenWindowFocused(scr)) {
            WMRect rect = wGetRectForHead(scr, wGetHeadForPointerLocation(scr));
            OpenSwitchMenu(scr, rect.pos.x + rect.size.width/2, rect.pos.y + rect.size.height/2, True);
        }
        break;
#endif /* !LITE */
    case WKBD_WINDOWMENU:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin))
            OpenWindowMenu(wwin, wwin->frame_x,
                           wwin->frame_y+wwin->frame->top_width, True);
        break;
    case WKBD_MINIATURIZE:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin)
            && !WFLAGP(wwin, no_miniaturizable)) {
            CloseWindowMenu(scr);

            if (wwin->protocols.MINIATURIZE_WINDOW)
                wClientSendProtocol(wwin, _XA_GNUSTEP_WM_MINIATURIZE_WINDOW,
                                    event->xbutton.time);
            else {
                wIconifyWindow(wwin);
            }
        }
        break;
    case WKBD_HIDE:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin)) {
            WApplication *wapp = wApplicationOf(wwin->main_window);
            CloseWindowMenu(scr);

            if (wapp && !WFLAGP(wapp->main_window_desc, no_appicon)) {
                wHideApplication(wapp);
            }
        }
        break;
    case WKBD_HIDE_OTHERS:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin)) {
            CloseWindowMenu(scr);

            wHideOtherApplications(wwin);
        }
        break;
    case WKBD_MAXIMIZE:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
            int newdir = (MAX_VERTICAL|MAX_HORIZONTAL);

            CloseWindowMenu(scr);

            if (wwin->flags.maximized == newdir) {
                wUnmaximizeWindow(wwin);
            } else {
                wMaximizeWindow(wwin, newdir|MAX_KEYBOARD);
            }
        }
        break;
    case WKBD_VMAXIMIZE:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
            int newdir = (MAX_VERTICAL ^ wwin->flags.maximized);

            CloseWindowMenu(scr);

            if (newdir) {
                wMaximizeWindow(wwin, newdir|MAX_KEYBOARD);
            } else {
                wUnmaximizeWindow(wwin);
            }
        }
        break;
    case WKBD_HMAXIMIZE:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
            int newdir = (MAX_HORIZONTAL ^ wwin->flags.maximized);

            CloseWindowMenu(scr);

            if (newdir) {
                wMaximizeWindow(wwin, newdir|MAX_KEYBOARD);
            } else {
                wUnmaximizeWindow(wwin);
            }
        }
        break;
    case WKBD_RAISE:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin)) {
            CloseWindowMenu(scr);

            wRaiseFrame(wwin->frame->core);
        }
        break;
    case WKBD_LOWER:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin)) {
            CloseWindowMenu(scr);

            wLowerFrame(wwin->frame->core);
        }
        break;
    case WKBD_RAISELOWER:
        /* raise or lower the window under the pointer, not the
         * focused one
         */
        wwin = windowUnderPointer(scr);
        if (wwin)
            wRaiseLowerFrame(wwin->frame->core);
        break;
    case WKBD_SHADE:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin) && !WFLAGP(wwin, no_shadeable)) {
            if (wwin->flags.shaded)
                wUnshadeWindow(wwin);
            else
                wShadeWindow(wwin);
        }
        break;
    case WKBD_MOVERESIZE:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin) &&
            (IS_RESIZABLE(wwin) || IS_MOVABLE(wwin))) {
            CloseWindowMenu(scr);

            wKeyboardMoveResizeWindow(wwin);
        }
        break;
    case WKBD_CLOSE:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin) && !WFLAGP(wwin, no_closable)) {
            CloseWindowMenu(scr);
            if (wwin->protocols.DELETE_WINDOW)
                wClientSendProtocol(wwin, _XA_WM_DELETE_WINDOW,
                                    event->xkey.time);
        }
        break;
    case WKBD_SELECT:
        if (ISMAPPED(wwin) && ISFOCUSED(wwin)) {
            wSelectWindow(wwin, !wwin->flags.selected);
        }
        break;
    case WKBD_FOCUSNEXT:
        StartWindozeCycle(wwin, event, True);
        break;

    case WKBD_FOCUSPREV:
        StartWindozeCycle(wwin, event, False);
        break;

#if (defined(__STDC__) && !defined(UNIXCPP)) || defined(ANSICPP)
#define GOTOWORKS(wk)	case WKBD_WORKSPACE##wk:\
    i = (scr->current_workspace/10)*10 + wk - 1;\
    if (wPreferences.ws_advance || i<scr->workspace_count)\
    wWorkspaceChange(scr, i);\
    break
#else
#define GOTOWORKS(wk)	case WKBD_WORKSPACE/**/wk:\
    i = (scr->current_workspace/10)*10 + wk - 1;\
    if (wPreferences.ws_advance || i<scr->workspace_count)\
    wWorkspaceChange(scr, i);\
    break
#endif
        GOTOWORKS(1);
        GOTOWORKS(2);
        GOTOWORKS(3);
        GOTOWORKS(4);
        GOTOWORKS(5);
        GOTOWORKS(6);
        GOTOWORKS(7);
        GOTOWORKS(8);
        GOTOWORKS(9);
        GOTOWORKS(10);
#undef GOTOWORKS
    case WKBD_NEXTWORKSPACE:
        wWorkspaceRelativeChange(scr, 1);
        break;
    case WKBD_PREVWORKSPACE:
        wWorkspaceRelativeChange(scr, -1);
        break;
    case WKBD_WINDOW1:
    case WKBD_WINDOW2:
    case WKBD_WINDOW3:
    case WKBD_WINDOW4:
    case WKBD_WINDOW5:
    case WKBD_WINDOW6:
    case WKBD_WINDOW7:
    case WKBD_WINDOW8:
    case WKBD_WINDOW9:
    case WKBD_WINDOW10:

        index = command-WKBD_WINDOW1;

        if (scr->shortcutWindows[index]) {
            WMArray *list = scr->shortcutWindows[index];
            int cw;
            int count = WMGetArrayItemCount(list);
            WWindow *twin;
            WMArrayIterator iter;
            WWindow *wwin;

            wUnselectWindows(scr);
            cw = scr->current_workspace;

            WM_ETARETI_ARRAY(list, wwin, iter) {
                if (count > 1)
                    wWindowChangeWorkspace(wwin, cw);

                wMakeWindowVisible(wwin);

                if (count > 1)
                    wSelectWindow(wwin, True);
            }

            /* rotate the order of windows, to create a cycling effect */
            twin = WMGetFromArray(list, 0);
            WMDeleteFromArray(list, 0);
            WMAddToArray(list, twin);

        } else if (wwin && ISMAPPED(wwin) && ISFOCUSED(wwin)) {
            if (scr->shortcutWindows[index]) {
                WMFreeArray(scr->shortcutWindows[index]);
                scr->shortcutWindows[index] = NULL;
            }

            if (wwin->flags.selected && scr->selected_windows) {
                scr->shortcutWindows[index] =
                    WMDuplicateArray(scr->selected_windows);
                /*WMRemoveFromArray(scr->shortcutWindows[index], wwin);
                 WMInsertInArray(scr->shortcutWindows[index], 0, wwin);*/
            } else {
                scr->shortcutWindows[index] = WMCreateArray(4);
                WMAddToArray(scr->shortcutWindows[index], wwin);
            }

            wSelectWindow(wwin, !wwin->flags.selected);
            XFlush(dpy);
            wusleep(3000);
            wSelectWindow(wwin, !wwin->flags.selected);
            XFlush(dpy);

        } else if (scr->selected_windows
                   && WMGetArrayItemCount(scr->selected_windows)) {

            if (wwin->flags.selected && scr->selected_windows) {
                if (scr->shortcutWindows[index]) {
                    WMFreeArray(scr->shortcutWindows[index]);
                }
                scr->shortcutWindows[index] =
                    WMDuplicateArray(scr->selected_windows);
            }
        }

        break;

    case WKBD_SWITCH_SCREEN:
        if (wScreenCount > 1) {
            WScreen *scr2;
            int i;

            /* find index of this screen */
            for (i = 0; i < wScreenCount; i++) {
                if (wScreenWithNumber(i) == scr)
                    break;
            }
            i++;
            if (i >= wScreenCount) {
                i = 0;
            }
            scr2 = wScreenWithNumber(i);

            if (scr2) {
                XWarpPointer(dpy, scr->root_win, scr2->root_win, 0, 0, 0, 0,
                             scr2->scr_width/2, scr2->scr_height/2);
            }
        }
        break;

    case WKBD_NEXTWSLAYER:
    case WKBD_PREVWSLAYER:
        {
            int row, column;

            row = scr->current_workspace/10;
            column = scr->current_workspace%10;

            if (command==WKBD_NEXTWSLAYER) {
                if ((row+1)*10 < scr->workspace_count)
                    wWorkspaceChange(scr, column+(row+1)*10);
            } else {
                if (row > 0)
                    wWorkspaceChange(scr, column+(row-1)*10);
            }
        }
        break;
    case WKBD_CLIPLOWER:
        if (!wPreferences.flags.noclip)
            wDockLower(scr->workspaces[scr->current_workspace]->clip);
        break;
    case WKBD_CLIPRAISE:
        if (!wPreferences.flags.noclip)
            wDockRaise(scr->workspaces[scr->current_workspace]->clip);
        break;
    case WKBD_CLIPRAISELOWER:
        if (!wPreferences.flags.noclip)
            wDockRaiseLower(scr->workspaces[scr->current_workspace]->clip);
        break;
#ifdef KEEP_XKB_LOCK_STATUS
    case WKBD_TOGGLE:
        if(wPreferences.modelock) {
            /*toggle*/
            wwin = scr->focused_window;

            if (wwin && wwin->flags.mapped
                && wwin->frame->workspace == wwin->screen_ptr->current_workspace
                && !wwin->flags.miniaturized && !wwin->flags.hidden) {
                XkbGetState(dpy,XkbUseCoreKbd,&staterec);

                wwin->frame->languagemode = wwin->frame->last_languagemode;
                wwin->frame->last_languagemode = staterec.group;
                XkbLockGroup(dpy,XkbUseCoreKbd, wwin->frame->languagemode);

            }
        }
        break;
#endif /* KEEP_XKB_LOCK_STATUS */
#ifdef VIRTUAL_DESKTOP
    case WKBD_VDESK_LEFT:
        wWorkspaceKeyboardMoveDesktop(scr, VEC_LEFT);
        break;

    case WKBD_VDESK_RIGHT:
        wWorkspaceKeyboardMoveDesktop(scr, VEC_RIGHT);
        break;

    case WKBD_VDESK_UP:
        wWorkspaceKeyboardMoveDesktop(scr, VEC_UP);
        break;

    case WKBD_VDESK_DOWN:
        wWorkspaceKeyboardMoveDesktop(scr, VEC_DOWN);
        break;
#endif

    }
}


static void
handleMotionNotify(XEvent *event)
{
    WScreen *scr = wScreenForRootWindow(event->xmotion.root);

    if (wPreferences.scrollable_menus) {
        WMPoint p = wmkpoint(event->xmotion.x_root, event->xmotion.y_root);
        WMRect rect = wGetRectForHead(scr, wGetHeadForPoint(scr, p));

        if (scr->flags.jump_back_pending ||
            p.x <= (rect.pos.x + 1) ||
            p.x >= (rect.pos.x + rect.size.width - 2) ||
            p.y <= (rect.pos.y + 1) ||
            p.y >= (rect.pos.y + rect.size.height - 2)) {
            WMenu *menu;
#ifdef DEBUG
            printf("pointer at screen edge\n");
#endif
            menu = wMenuUnderPointer(scr);
            if (menu!=NULL)
                wMenuScroll(menu, event);
        }
    }
}


static void
handleVisibilityNotify(XEvent *event)
{
    WWindow *wwin;

    wwin = wWindowFor(event->xvisibility.window);
    if (!wwin)
        return;
    wwin->flags.obscured =
        (event->xvisibility.state == VisibilityFullyObscured);
}


