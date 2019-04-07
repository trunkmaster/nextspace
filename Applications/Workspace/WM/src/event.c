/* event.c- event loop and handling
 *
 *  Window Maker window manager
 *
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

#include "wconfig.h"

#ifdef HAVE_INOTIFY
#include <sys/select.h>
#include <sys/inotify.h>
#endif

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
# include <X11/extensions/shape.h>
#endif
#ifdef USE_DOCK_XDND
#include "xdnd.h"
#endif

#ifdef USE_RANDR
#include <X11/extensions/Xrandr.h>
#endif

#ifdef KEEP_XKB_LOCK_STATUS
#include <X11/XKBlib.h>
#endif				/* KEEP_XKB_LOCK_STATUS */

#include "WindowMaker.h"
#include "window.h"
#include "actions.h"
#include "client.h"
#include "main.h"
#include "cycling.h"
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
#include "wmspec.h"
#include "rootmenu.h"
#include "colormap.h"
#include "screen.h"
#include "shutdown.h"
#include "misc.h"
#include "event.h"
#include "winmenu.h"
#include "switchmenu.h"
#include "wsmap.h"

#ifdef NEXTSPACE
#include <Workspace+WindowMaker.h>
extern void WWMIconYardShowIcons(WScreen *screen);
extern void WWMIconYardHideIcons(WScreen *screen);
extern void WWMDockShowIcons(WDock *dock);
extern void WWMDockHideIcons(WDock *dock);
#endif

#define MOD_MASK wPreferences.modifier_mask

/************ Local stuff ***********/

static void saveTimestamp(XEvent *event);
static void handleColormapNotify(XEvent *event);
static void handleMapNotify(XEvent *event);
static void handleUnmapNotify(XEvent *event);
static void handleButtonPress(XEvent *event);
#ifdef NEXTSPACE
static void handleButtonRelease(XEvent * event);
static void handleKeyRelease(XEvent * event);
#endif
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
static void handle_inotify_events(void);
static void handle_selection_request(XSelectionRequestEvent *event);
static void handle_selection_clear(XSelectionClearEvent *event);
static void wdelete_death_handler(WMagicNumber id);


#ifdef USE_XSHAPE
static void handleShapeNotify(XEvent *event);
#endif

#ifdef KEEP_XKB_LOCK_STATUS
static void handleXkbBellNotify(XkbEvent *event);
static void handleXkbIndicatorStateNotify(XkbEvent *event);
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

static WMArray *deathHandlers = NULL;

WMagicNumber wAddDeathHandler(pid_t pid, WDeathHandler * callback, void *cdata)
{
	DeathHandler *handler;

	handler = malloc(sizeof(DeathHandler));
	if (!handler)
		return 0;

	handler->pid = pid;
	handler->callback = callback;
	handler->client_data = cdata;

	if (!deathHandlers)
		deathHandlers = WMCreateArrayWithDestructor(8, free);

	WMAddToArray(deathHandlers, handler);

	return handler;
}

static void wdelete_death_handler(WMagicNumber id)
{
	DeathHandler *handler = (DeathHandler *) id;

	if (!handler || !deathHandlers)
		return;

	/* array destructor will call free(handler) */
	WMRemoveFromArray(deathHandlers, handler);
}

void DispatchEvent(XEvent * event)
{
	if (deathHandlers)
		handleDeadProcess();

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
		wDefaultsCheckDomains(NULL);
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

#ifdef NEXTSPACE
	case KeyRelease:
		handleKeyRelease(event);
		break;
#endif
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

#ifdef NEXTSPACE
	case ButtonRelease:
		handleButtonRelease(event);
          break;
#endif
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
#ifdef USE_RANDR
		if (event->xconfigure.window == DefaultRootWindow(dpy))
			XRRUpdateConfiguration(event);
#endif
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

#ifdef HAVE_INOTIFY
/*
 *----------------------------------------------------------------------
 * handle_inotify_events-
 * 	Check for inotify events
 *
 * Returns:
 * 	After reading events for the given file descriptor (fd) and
 *     watch descriptor (wd)
 *
 * Side effects:
 * 	Calls wDefaultsCheckDomains if config database is updated
 *----------------------------------------------------------------------
 */
static void handle_inotify_events(void)
{
	ssize_t eventQLength;
	size_t i = 0;
	/* Make room for at lease 5 simultaneous events, with path + filenames */
	char buff[ (sizeof(struct inotify_event) + NAME_MAX + 1) * 5 ];
	/* Check config only once per read of the event queue */
	int oneShotFlag = 0;

	/*
	 * Read off the queued events
	 * queue overflow is not checked (IN_Q_OVERFLOW). In practise this should
	 * not occur; the block is on Xevents, but a config file change will normally
	 * occur as a result of an Xevent - so the event queue should never have more than
	 * a few entries before a read().
	 */
	eventQLength = read(w_global.inotify.fd_event_queue,
	                    buff, sizeof(buff) );

	if (eventQLength < 0) {
		wwarning(_("read problem when trying to get INotify event: %s"), strerror(errno));
		return;
	}

	/* check what events occured */
	/* Should really check wd here too, but for now we only have one watch! */
	while (i < eventQLength) {
		struct inotify_event *pevent = (struct inotify_event *)&buff[i];

		/*
		 * see inotify.h for event types.
		 */
		if (pevent->mask & IN_DELETE_SELF) {
			wwarning(_("the defaults database has been deleted!"
				   " Restart Window Maker to create the database" " with the default settings"));

			if (w_global.inotify.fd_event_queue >= 0) {
				close(w_global.inotify.fd_event_queue);
				w_global.inotify.fd_event_queue = -1;
			}
		}
		if (pevent->mask & IN_UNMOUNT) {
			wwarning(_("the unit containing the defaults database has"
				   " been unmounted. Setting --static mode." " Any changes will not be saved."));

			if (w_global.inotify.fd_event_queue >= 0) {
				close(w_global.inotify.fd_event_queue);
				w_global.inotify.fd_event_queue = -1;
			}

			wPreferences.flags.noupdates = 1;
		}
		if ((pevent->mask & IN_MODIFY) && oneShotFlag == 0) {
			wwarning(_("Inotify: Reading config files in defaults database."));
			wDefaultsCheckDomains(NULL);
			oneShotFlag = 1;
		}

		/* move to next event in the buffer */
		i += sizeof(struct inotify_event) + pevent->len;
	}
}
#endif /* HAVE_INOTIFY */

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
#ifdef HAVE_INOTIFY
	struct timeval time;
	fd_set rfds;
	int retVal = 0;

	if (w_global.inotify.fd_event_queue < 0 || w_global.inotify.wd_defaults < 0)
		retVal = -1;
#endif

	for (;;) {

		WMNextEvent(dpy, &event);	/* Blocks here */
		WMHandleEvent(&event);
#ifdef HAVE_INOTIFY
		if (retVal != -1) {
			time.tv_sec = 0;
			time.tv_usec = 0;
			FD_ZERO(&rfds);
			FD_SET(w_global.inotify.fd_event_queue, &rfds);

			/* check for available read data from inotify - don't block! */
			retVal = select(w_global.inotify.fd_event_queue + 1, &rfds, NULL, NULL, &time);

			if (retVal < 0) {	/* an error has occured */
				wwarning(_("select failed. The inotify instance will be closed."
					   " Changes to the defaults database will require"
					   " a restart to take effect."));
				close(w_global.inotify.fd_event_queue);
				w_global.inotify.fd_event_queue = -1;
				continue;
			}
			if (FD_ISSET(w_global.inotify.fd_event_queue, &rfds))
				handle_inotify_events();
		}
#endif
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
		WMNextEvent(dpy, &event);
		WMHandleEvent(&event);
		count--;
	}
}

Bool IsDoubleClick(WScreen * scr, XEvent * event)
{
	if ((scr->last_click_time > 0) &&
	    (event->xbutton.time - scr->last_click_time <= wPreferences.dblclick_time)
	    && (event->xbutton.button == scr->last_click_button)
	    && (event->xbutton.window == scr->last_click_window)) {

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
		wwarning("stack overflow: too many dead processes");
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

		for (i = WMGetArrayItemCount(deathHandlers) - 1; i >= 0; i--) {
			tmp = WMGetFromArray(deathHandlers, i);
			if (!tmp)
				continue;

			if (tmp->pid == deadProcesses[deadProcessPtr].pid) {
				(*tmp->callback) (tmp->pid,
						  deadProcesses[deadProcessPtr].exit_status, tmp->client_data);
				wdelete_death_handler(tmp);
			}
		}
	}
}

static void saveTimestamp(XEvent * event)
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

static int matchWindow(const void *item, const void *cdata)
{
	return (((WFakeGroupLeader *) item)->origLeader == (Window) cdata);
}

static void handleExtensions(XEvent * event)
{
#ifdef USE_XSHAPE
	if (w_global.xext.shape.supported && event->type == (w_global.xext.shape.event_base + ShapeNotify)) {
		handleShapeNotify(event);
	}
#endif
#ifdef KEEP_XKB_LOCK_STATUS
	if (wPreferences.modelock && (event->type == w_global.xext.xkb.event_base)) {
    XkbEvent *e = (XkbEvent *)event;
    /* fprintf(stderr, "[WM] XKB event occured! = %i,%i\n", */
    /*         event->xany.type, e->any.xkb_type); */
    if (e->any.xkb_type == XkbBellNotify) {
      handleXkbBellNotify(e);
    }
    else if (e->any.xkb_type == XkbIndicatorStateNotify) {
      handleXkbIndicatorStateNotify(e);
    }
	}
#endif				/*KEEP_XKB_LOCK_STATUS */
#ifdef USE_RANDR
	if (w_global.xext.randr.supported && event->type == (w_global.xext.randr.event_base + RRScreenChangeNotify)) {
		/* From xrandr man page: "Clients must call back into Xlib using
		 * XRRUpdateConfiguration when screen configuration change notify
		 * events are generated */
		XRRUpdateConfiguration(event);
#ifdef NEXTSPACE                
		for (int i = 0; i < w_global.screen_count; i++) {
			XWUpdateScreenInfo(wScreenWithNumber(i));
		}
#else
		WCHANGE_STATE(WSTATE_RESTARTING);
		Shutdown(WSRestartPreparationMode);
		Restart(NULL,True);
#endif
	}
#endif
}

static void handleMapRequest(XEvent * ev)
{
	WWindow *wwin;
	WScreen *scr = NULL;
	Window window = ev->xmaprequest.window;

	scr = wScreenForRootWindow(ev->xmaprequest.parent);

	wwin = wWindowFor(window);
	if (wwin != NULL) {
    /* fprintf(stderr, "[WM] MapRequest %lu\n", wwin->client_win); */
		if (!wwin->flags.is_gnustep && wwin->flags.shaded) {
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
		} else if (WINDOW_LEVEL(wwin) == WMMainMenuLevel &&
               wwin->flags.is_gnustep && wwin->flags.mapped == 0) {
      /* GNUstep app main menu window is managed but unmapped */
      WApplication *wapp = wApplicationOf(wwin->main_window);
      int last_focused_mapped = 0;

      if (wapp->last_focused)
        last_focused_mapped = wapp->last_focused->flags.mapped;
      
      wWindowMap(wwin);
      if (last_focused_mapped == 0 || wwin == wapp->menu_win)
        wSetFocusTo(scr, wwin);
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
				wHideApplication(wapp);
			}
		}
	}
}

static void handleDestroyNotify(XEvent * event)
{
	WWindow *wwin;
	WApplication *app;
	Window window = event->xdestroywindow.window;
	WScreen *scr = wScreenForRootWindow(event->xdestroywindow.event);
	int widx;

	wwin = wWindowFor(window);
	if (wwin) {
    /* fprintf(stderr, "[WM, event.c] DestroyNotify will unmanage window:%lu\n", window); */
#ifdef NEXTSPACE
		dispatch_sync(workspace_q, ^{ XWApplicationDidCloseWindow(wwin); });
#endif
		wUnmanageWindow(wwin, False, True);
	}

	if (scr != NULL) {
		while ((widx = WMFindInArray(scr->fakeGroupLeaders, matchWindow, (void *)window)) != WANotFound) {
			WFakeGroupLeader *fPtr;

			fPtr = WMGetFromArray(scr->fakeGroupLeaders, widx);
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

static void handleExpose(XEvent * event)
{
	WObjDescriptor *desc;
	XEvent ev;

	while (XCheckTypedWindowEvent(dpy, event->xexpose.window, Expose, &ev)) ;

	if (XFindContext(dpy, event->xexpose.window, w_global.context.client_win, (XPointer *) & desc) == XCNOENT) {
		return;
	}

	if (desc->handle_expose) {
		(*desc->handle_expose) (desc, event);
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
			wWorkspaceRelativeChange(scr, 1);
		else
			wWorkspaceRelativeChange(scr, -1);
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
	case WA_MOVE_PREVWORKSPACE:
		wWorkspaceRelativeChange(scr, -1);
		break;
	case WA_MOVE_NEXTWORKSPACE:
		wWorkspaceRelativeChange(scr, 1);
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
static void handleButtonPress(XEvent * event)
{
	WObjDescriptor *desc;
	WScreen *scr;

	scr = wScreenForRootWindow(event->xbutton.root);
  
#ifdef NEXTSPACE
  // reset current focused window button beacuse ButtonPress may change focus
	WWindow *wwin = scr->focused_window;
	if (wwin && wwin->client_win != scr->no_focus_win && wwin->frame &&
			wwin->frame->left_button &&
			event->xbutton.window != wwin->frame->left_button->window &&
			wwin->frame->right_button &&
			event->xbutton.window != wwin->frame->right_button->window) {
		scr->flags.modifier_pressed = 0;
		wWindowUpdateButtonImages(wwin);
	}
#endif

#ifdef BALLOON_TEXT
	wBalloonHide(scr);
#endif

	if (!wPreferences.disable_root_mouse && event->xbutton.window == scr->root_win) {
		if (event->xbutton.button == Button1 && wPreferences.mouse_button1 != WA_NONE) {
#ifdef NEXTSPACE
			if (scr->focused_window && scr->focused_window->flags.is_gnustep) {
				XSendEvent(dpy, scr->focused_window->client_win, False, ButtonPressMask, event);
			}
			else {
				XSendEvent(dpy, scr->dock->icon_array[0]->icon->icon_win, False, ButtonPressMask, event);
			}
#else
			executeButtonAction(scr, event, wPreferences.mouse_button1);
#endif
		} else if (event->xbutton.button == Button2 && wPreferences.mouse_button2 != WA_NONE) {
			executeButtonAction(scr, event, wPreferences.mouse_button2);
		} else if (event->xbutton.button == Button3 && wPreferences.mouse_button3 != WA_NONE) {
#ifdef NEXTSPACE
			if (scr->focused_window && scr->focused_window->flags.is_gnustep) {
				XSendEvent(dpy, scr->focused_window->client_win, False, ButtonPressMask, event);
			}
			else {
				XSendEvent(dpy, scr->dock->icon_array[0]->icon->icon_win, False, ButtonPressMask, event);
			}
#else
			executeButtonAction(scr, event, wPreferences.mouse_button3);
#endif
		} else if (event->xbutton.button == Button8 && wPreferences.mouse_button8 != WA_NONE) {
			executeButtonAction(scr, event, wPreferences.mouse_button8);
		}else if (event->xbutton.button == Button9 && wPreferences.mouse_button9 != WA_NONE) {
			executeButtonAction(scr, event, wPreferences.mouse_button9);
		} else if (event->xbutton.button == Button4 && wPreferences.mouse_wheel_scroll != WA_NONE) {
			executeWheelAction(scr, event, wPreferences.mouse_wheel_scroll);
		} else if (event->xbutton.button == Button5 && wPreferences.mouse_wheel_scroll != WA_NONE) {
			executeWheelAction(scr, event, wPreferences.mouse_wheel_scroll);
		} else if (event->xbutton.button == Button6 && wPreferences.mouse_wheel_tilt != WA_NONE) {
			executeWheelAction(scr, event, wPreferences.mouse_wheel_tilt);
		} else if (event->xbutton.button == Button7 && wPreferences.mouse_wheel_tilt != WA_NONE) {
			executeWheelAction(scr, event, wPreferences.mouse_wheel_tilt);
		}
	}

	desc = NULL;
	if (XFindContext(dpy, event->xbutton.subwindow, w_global.context.client_win, (XPointer *) & desc) == XCNOENT) {
		if (XFindContext(dpy, event->xbutton.window, w_global.context.client_win, (XPointer *) & desc) == XCNOENT) {
			return;
		}
	}

	if (desc->parent_type == WCLASS_WINDOW) {
		XSync(dpy, 0);
		if (event->xbutton.state & ( MOD_MASK | ControlMask)) {
			XAllowEvents(dpy, AsyncPointer, CurrentTime);
		}
    else if (wPreferences.ignore_focus_click) {
			XAllowEvents(dpy, AsyncPointer, CurrentTime);
		}
    else {
			XAllowEvents(dpy, ReplayPointer, CurrentTime);
		}
		XSync(dpy, 0);
	}
  else if (desc->parent_type == WCLASS_APPICON
             || desc->parent_type == WCLASS_MINIWINDOW
             || desc->parent_type == WCLASS_DOCK_ICON) {
		if (event->xbutton.state & wPreferences.modifier_mask) {
      WAppIcon *appicon = wAppIconFor(event->xbutton.window);
      WAppIcon *appicon0 = scr->dock->icon_array[0];
      if ((desc->parent_type == WCLASS_DOCK_ICON) &&
          (appicon->icon->icon_win == appicon0->icon->icon_win)) {
        if (WWMDockLevel() == WMDockLevel)
          WWMSetDockLevel(WMNormalLevel);
        else {
          WWMSetDockLevel(WMDockLevel);
        }
        XUngrabPointer(dpy, CurrentTime);
        return;
      }
      else {
        XSync(dpy, 0);
        XAllowEvents(dpy, AsyncPointer, CurrentTime);
        XSync(dpy, 0);
      }
		}
	}

	if (desc->handle_mousedown != NULL) {
		(*desc->handle_mousedown) (desc, event);
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

#ifdef NEXTSPACE
static void handleButtonRelease(XEvent * event)
{
	WScreen *scr = wScreenForRootWindow(event->xbutton.root);

	if (!wPreferences.disable_root_mouse && event->xbutton.window == scr->root_win
			&& event->xbutton.button == Button3) {
		if (scr->focused_window && !strcmp(scr->focused_window->wm_class, "GNUstep")) {
			XSendEvent(dpy, scr->focused_window->client_win, True, ButtonReleaseMask, event);
		}
		else {
			XSendEvent(dpy, scr->dock->icon_array[0]->icon->icon_win, False, ButtonReleaseMask, event);
		}
	}
}
#endif

static void handleMapNotify(XEvent * event)
{
	WWindow *wwin;

	wwin = wWindowFor(event->xmap.event);
	if (wwin && wwin->client_win == event->xmap.event) {
    /* fprintf(stderr, "[WM] MapNotify %lu\n", wwin->client_win); */
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

static void handleUnmapNotify(XEvent * event)
{
	WWindow *wwin;
	XEvent ev;
	Bool withdraw = False;

	/* only process windows with StructureNotify selected
	 * (ignore SubstructureNotify) */
  
  /* fprintf(stderr, "[WM] handleUnmapNotify for window %lu.\n", event->xunmap.window); */
  
	wwin = wWindowFor(event->xunmap.window);
	if (!wwin)
		return;

	/* whether the event is a Withdrawal request */
	if (event->xunmap.event == wwin->screen_ptr->root_win && event->xunmap.send_event)
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
	if (XCheckTypedWindowEvent(dpy, wwin->client_win, DestroyNotify, &ev)) {
		DispatchEvent(&ev);
	} else {
		Bool reparented = False;

		if (XCheckTypedWindowEvent(dpy, wwin->client_win, ReparentNotify, &ev))
			reparented = True;

		/* withdraw window */
		wwin->flags.mapped = 0;
		if (!reparented)
			wClientSetState(wwin, WithdrawnState, None);

    if (WINDOW_LEVEL(wwin) != WMMainMenuLevel) {
      /* fprintf(stderr, "[WM, event.c] UnmapNotify will unmanage window:%lu is_gnustep=%i\n", */
      /*         event->xunmap.window, wwin->flags.is_gnustep); */
      /* if the window was reparented, do not reparent it back to the
       * root window */
      wUnmanageWindow(wwin, !reparented, False);
    }
    else {
      /* FIXME: temporary fix to switch focus to previously active app after 
         GNUstep app "Hide" menu item click */
      /* WApplication *wapp = wApplicationOf(wwin->main_window); */
      /* WScreen *scr = wwin->screen_ptr; */
      /* WWindow *wlist = scr->focused_window; */

      /* if (wapp && !wapp->flags.hidden) { */
      /*   while (wlist) { */
      /*     if (!WFLAGP(wlist, no_focusable) && !wlist->flags.hidden */
      /*         && (wlist->flags.mapped || wlist->flags.shaded)) */
      /*       break; */
      /*     wlist = wlist->prev; */
      /*   } */
      /*   if (wlist != scr->focused_window) { */
      /*     wSetFocusTo(scr, wlist); */
      /*   } */
      /* } */

      /* if (wapp && wapp->flags.hidden) { */
      /*   wSetFocusTo(wwin->screen_ptr, NULL); */
      /* } */
    }
	}
	XUngrabServer(dpy);
}

static void handleConfigureRequest(XEvent * event)
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

static void handlePropertyNotify(XEvent * event)
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
		wClientCheckProperty(wapp->main_window_desc, &event->xproperty);
	}
}

static void handleClientMessage(XEvent * event)
{
	WWindow *wwin;
	WObjDescriptor *desc;

	/* handle transition from Normal to Iconic state */
	if (event->xclient.message_type == w_global.atom.wm.change_state
	    && event->xclient.format == 32 && event->xclient.data.l[0] == IconicState) {

		wwin = wWindowFor(event->xclient.window);
		if (!wwin)
			return;
		if (!wwin->flags.miniaturized)
			wIconifyWindow(wwin);
	} else if (event->xclient.message_type == w_global.atom.wm.colormap_notify && event->xclient.format == 32) {
		WScreen *scr = wScreenForRootWindow(event->xclient.window);

		if (!scr)
			return;

		if (event->xclient.data.l[1] == 1) {	/* starting */
			wColormapAllowClientInstallation(scr, True);
		} else {	/* stopping */
			wColormapAllowClientInstallation(scr, False);
		}
	} else if (event->xclient.message_type == w_global.atom.wmaker.command) {

		char *command;
		size_t len;

		len = sizeof(event->xclient.data.b) + 1;
		command = wmalloc(len);
		strncpy(command, event->xclient.data.b, sizeof(event->xclient.data.b));

		if (strncmp(command, "Reconfigure", sizeof("Reconfigure")) == 0) {
			wwarning(_("Got Reconfigure command"));
			wDefaultsCheckDomains(NULL);
		} else {
			wwarning(_("Got unknown command %s"), command);
		}

		wfree(command);

	} else if (event->xclient.message_type == w_global.atom.wmaker.wm_function) {
		WApplication *wapp;
		int done = 0;
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
	} else if (event->xclient.message_type == w_global.atom.gnustep.wm_attr) {
		wwin = wWindowFor(event->xclient.window);
		if (!wwin)
			return;
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
		WScreen *scr = wScreenForRootWindow(event->xclient.window);
		if (!scr)
			return;
		scr->flags.ignore_focus_events = event->xclient.data.l[0] ? 1 : 0;
	} else if (wNETWMProcessClientMessage(&event->xclient)) {
		/* do nothing */
#ifdef USE_DOCK_XDND
	} else if (wXDNDProcessClientMessage(&event->xclient)) {
		/* do nothing */
#endif	/* USE_DOCK_XDND */
	} else {
		/*
		 * Non-standard thing, but needed by OffiX DND.
		 * For when the icon frame gets a ClientMessage
		 * that should have gone to the icon_window.
		 */
		if (XFindContext(dpy, event->xbutton.window, w_global.context.client_win, (XPointer *) & desc) != XCNOENT) {
			struct WIcon *icon = NULL;

			if (desc->parent_type == WCLASS_MINIWINDOW) {
				icon = (WIcon *) desc->parent;
			} else if (desc->parent_type == WCLASS_DOCK_ICON || desc->parent_type == WCLASS_APPICON) {
				icon = ((WAppIcon *) desc->parent)->icon;
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

static void raiseWindow(WScreen * scr)
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

static void handleEnterNotify(XEvent * event)
{
	WWindow *wwin;
	WObjDescriptor *desc = NULL;
	XEvent ev;
	WScreen *scr = wScreenForRootWindow(event->xcrossing.root);

	if (XCheckTypedWindowEvent(dpy, event->xcrossing.window, LeaveNotify, &ev)) {
		/* already left the window... */
		saveTimestamp(&ev);
		if (ev.xcrossing.mode == event->xcrossing.mode && ev.xcrossing.detail == event->xcrossing.detail) {
			return;
		}
	}

	if (XFindContext(dpy, event->xcrossing.window, w_global.context.client_win, (XPointer *) & desc) != XCNOENT) {
		if (desc->handle_enternotify)
			(*desc->handle_enternotify) (desc, event);
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
		/* set auto raise timer even if in focus-follows-mouse mode
		 * and the event is for the frame window, even if the window
		 * has focus already.  useful if you move the pointer from a focused
		 * window to the root window and back pretty fast
		 *
		 * set focus if in focus-follows-mouse mode and the event
		 * is for the frame window and window doesn't have focus yet */
		if (wPreferences.focus_mode == WKF_SLOPPY
		    && wwin->frame->core->window == event->xcrossing.window && !scr->flags.doing_alt_tab) {

			if (!wwin->flags.focused && !WFLAGP(wwin, no_focusable))
				wSetFocusTo(scr, wwin);

			if (scr->autoRaiseTimer)
				WMDeleteTimerHandler(scr->autoRaiseTimer);
			scr->autoRaiseTimer = NULL;

			if (wPreferences.raise_delay && !WFLAGP(wwin, no_focusable)) {
				scr->autoRaiseWindow = wwin->frame->core->window;
				scr->autoRaiseTimer
				    = WMAddTimerHandler(wPreferences.raise_delay, (WMCallback *) raiseWindow, scr);
			}
		}
		/* Install colormap for window, if the colormap installation mode
		 * is colormap_follows_mouse */
		if (wPreferences.colormap_mode == WCM_POINTER) {
			if (wwin->client_win == event->xcrossing.window)
				wColormapInstallForWindow(scr, wwin);
			else
				wColormapInstallForWindow(scr, NULL);
		}
	}

	if (event->xcrossing.window == event->xcrossing.root
	    && event->xcrossing.detail == NotifyNormal
	    && event->xcrossing.detail != NotifyInferior && wPreferences.focus_mode != WKF_CLICK) {

		wSetFocusTo(scr, scr->focused_window);
	}
#ifdef BALLOON_TEXT
	wBalloonEnteredObject(scr, desc);
#endif
}

static void handleLeaveNotify(XEvent * event)
{
	WObjDescriptor *desc = NULL;

	if (XFindContext(dpy, event->xcrossing.window, w_global.context.client_win, (XPointer *) & desc) != XCNOENT) {
		if (desc->handle_leavenotify)
			(*desc->handle_leavenotify) (desc, event);
	}
}

#ifdef USE_XSHAPE
static void handleShapeNotify(XEvent * event)
{
	XShapeEvent *shev = (XShapeEvent *) event;
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
#endif				/* USE_XSHAPE */

#ifdef KEEP_XKB_LOCK_STATUS
static void handleXkbBellNotify(XkbEvent *event)
{
  // Play sound specified in ~/Library/Preferences/.NextSpace/NXGlobalDomain
  // as NXSystemBeep.
  fprintf(stderr, "[WM] XKB event is XkbBellNotify!\n");
}
/* please help ]d if you know what to do */
static void handleXkbIndicatorStateNotify(XkbEvent *event)
{
	WWindow *wwin;
	WScreen *scr;
	XkbStateRec staterec;
	int i;

	for (i = 0; i < w_global.screen_count; i++) {
		scr = wScreenWithNumber(i);
		wwin = scr->focused_window;
		if (wwin && wwin->flags.focused) {
			XkbGetState(dpy, XkbUseCoreKbd, &staterec);
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
#endif				/*KEEP_XKB_LOCK_STATUS */

static void handleColormapNotify(XEvent * event)
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

	if (reinstall && scr->current_colormap != None) {
		if (!scr->flags.colormap_stuff_blocked)
			XInstallColormap(dpy, scr->current_colormap);
	}
}

static void handleFocusIn(XEvent * event)
{
	WWindow *wwin;

	/*
	 * For applications that like stealing the focus.
	 */
	while (XCheckTypedEvent(dpy, FocusIn, event)) ;
	saveTimestamp(event);
	if (event->xfocus.mode == NotifyUngrab
	    || event->xfocus.mode == NotifyGrab || event->xfocus.detail > NotifyNonlinearVirtual) {
		return;
	}

	wwin = wWindowFor(event->xfocus.window);
	if (wwin && !wwin->flags.focused) {
		if (wwin->flags.mapped) {
			wSetFocusTo(wwin->screen_ptr, wwin);
			wRaiseFrame(wwin->frame->core);
		} else {
			wSetFocusTo(wwin->screen_ptr, NULL);
    }
	} else if (!wwin) {
		WScreen *scr = wScreenForWindow(event->xfocus.window);
		if (scr)
			wSetFocusTo(scr, NULL);
	}
}

static WWindow *windowUnderPointer(WScreen * scr)
{
	unsigned int mask;
	int foo;
	Window bar, win;

	if (XQueryPointer(dpy, scr->root_win, &bar, &win, &foo, &foo, &foo, &foo, &mask))
		return wWindowFor(win);
	return NULL;
}

static int CheckFullScreenWindowFocused(WScreen * scr)
{
	if (scr->focused_window && scr->focused_window->flags.fullscreen)
		return 1;
	else
		return 0;
}

static void handleKeyPress(XEvent * event)
{
	WScreen *scr = wScreenForRootWindow(event->xkey.root);
	WWindow *wwin = scr->focused_window;
	short i, widx;
	int modifiers;
	int command = -1;
#ifdef KEEP_XKB_LOCK_STATUS
	XkbStateRec staterec;
#endif				/*KEEP_XKB_LOCK_STATUS */

	/* ignore CapsLock */
	modifiers = event->xkey.state & w_global.shortcut.modifiers_mask;

#ifdef NEXTSPACE
  /* if (wwin && wwin->client_win) { */
  /*   fprintf(stderr, "[WindowMaker] handleKeyPress: %i state: %i mask: %i" */
  /*           " modifiers: %i window:%lu\n", */
  /*           event->xkey.keycode, event->xkey.state, MOD_MASK, */
  /*           modifiers, wwin->client_win); */
  /* } */
  
	if (((event->xkey.keycode == XKeysymToKeycode(dpy, XK_Super_L)) ||
       (event->xkey.keycode == XKeysymToKeycode(dpy, XK_Super_R))) &&
			modifiers == 0) {
    if (wwin && wwin->client_win != scr->no_focus_win &&
        event->xkey.window != event->xkey.root) {
      scr->flags.modifier_pressed = 1;
      wWindowUpdateButtonImages(wwin);
    }
	}
	else if (event->xkey.window != event->xkey.root &&
           event->xkey.window != scr->no_focus_win) {
		scr->flags.modifier_pressed = 0;
		wWindowUpdateButtonImages(wwin);
	}
#endif

	for (i = 0; i < WKBD_LAST; i++) {
		if (wKeyBindings[i].keycode == 0)
			continue;

		if (wKeyBindings[i].keycode == event->xkey.keycode &&
				(wKeyBindings[i].modifier == modifiers)) {
			command = i;
			break;
		}
	}

	if (command < 0) {
		if (!wRootMenuPerformShortcut(event)) {
			static int dontLoop = 0;

			if (dontLoop > 10) {
				wwarning("problem with key event processing code");
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
		}

    // Shortuct which does not overlap with WindowMaker was pressed -
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

  case WKBD_DOCKHIDESHOW:
    if (!wwin || strcmp(wwin->wm_instance, "Workspace") != 0) {
      if (scr->dock->mapped) {
        WWMDockHideIcons(scr->dock);
      }
      else {
        WWMDockShowIcons(scr->dock);
      }
    }
    else {
      XSendEvent(dpy, wwin->client_win, True, KeyPressMask, event);
    }
    break;
  case WKBD_YARDHIDESHOW:
    if (!wwin || strcmp(wwin->wm_instance, "Workspace") != 0) {
      if (scr->flags.icon_yard_mapped) {
        WWMIconYardHideIcons(scr);
      }
      else {
        WWMIconYardShowIcons(scr);
      }
    }
    else {
      XSendEvent(dpy, wwin->client_win, True, KeyPressMask, event);
    }
    break;
	case WKBD_ROOTMENU:
		/*OpenRootMenu(scr, event->xkey.x_root, event->xkey.y_root, True); */
		if (!CheckFullScreenWindowFocused(scr)) {
			WMRect rect = wGetRectForHead(scr, wGetHeadForPointerLocation(scr));
			OpenRootMenu(scr, rect.pos.x + rect.size.width / 2, rect.pos.y + rect.size.height / 2,
				     True);
		}
		break;
	case WKBD_WINDOWLIST:
		if (!CheckFullScreenWindowFocused(scr)) {
			WMRect rect = wGetRectForHead(scr, wGetHeadForPointerLocation(scr));
			OpenSwitchMenu(scr, rect.pos.x + rect.size.width / 2, rect.pos.y + rect.size.height / 2,
				       True);
		}
		break;

	case WKBD_WINDOWMENU:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin))
			OpenWindowMenu(wwin, wwin->frame_x, wwin->frame_y + wwin->frame->top_width, True);
		break;
	case WKBD_MINIMIZEALL:
		CloseWindowMenu(scr);
		wHideAll(scr);
		break;
	case WKBD_MINIATURIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && !WFLAGP(wwin, no_miniaturizable)) {
			CloseWindowMenu(scr);
			if (wwin->protocols.MINIATURIZE_WINDOW) {
        /* fprintf(stderr, "[WM] send WM_MINIATURIZE_WINDOW protocol message to client.\n"); */
        if (wwin->flags.is_gnustep) {
          XSendEvent(dpy, wwin->client_win, True, KeyPressMask, event);
        }
        else {
          wClientSendProtocol(wwin, w_global.atom.gnustep.wm_miniaturize_window,
                              event->xbutton.time);
        }
      }
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
        if (wwin->flags.is_gnustep) {
          XSendEvent(dpy, wwin->client_win, True, KeyPressMask, event);
        }
        else {
          wHideApplication(wapp);
        }
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
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_VERTICAL | MAX_HORIZONTAL | MAX_KEYBOARD);
		}
		break;
	case WKBD_VMAXIMIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_VERTICAL | MAX_KEYBOARD);
		}
		break;
	case WKBD_HMAXIMIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_HORIZONTAL | MAX_KEYBOARD);
		}
		break;
	case WKBD_LHMAXIMIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_VERTICAL | MAX_LEFTHALF | MAX_KEYBOARD);
		}
		break;
	case WKBD_RHMAXIMIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_VERTICAL | MAX_RIGHTHALF | MAX_KEYBOARD);
		}
		break;
	case WKBD_THMAXIMIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_HORIZONTAL | MAX_TOPHALF | MAX_KEYBOARD);
		}
		break;
	case WKBD_BHMAXIMIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_HORIZONTAL | MAX_BOTTOMHALF | MAX_KEYBOARD);
		}
		break;
	case WKBD_LTCMAXIMIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_LEFTHALF | MAX_TOPHALF | MAX_KEYBOARD);
		}
		break;
	case WKBD_RTCMAXIMIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_RIGHTHALF | MAX_TOPHALF | MAX_KEYBOARD);
		}
		break;
	case WKBD_LBCMAXIMIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_LEFTHALF | MAX_BOTTOMHALF | MAX_KEYBOARD);
		}
		 break;
	case WKBD_RBCMAXIMIZE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_RIGHTHALF | MAX_BOTTOMHALF | MAX_KEYBOARD);
		}
		break;
	case WKBD_MAXIMUS:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && IS_RESIZABLE(wwin)) {
			CloseWindowMenu(scr);

			handleMaximize(wwin, MAX_MAXIMUS | MAX_KEYBOARD);
		}
		break;
	case WKBD_OMNIPRESENT:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin)) {
			CloseWindowMenu(scr);

			wWindowSetOmnipresent(wwin, !wwin->flags.omnipresent);
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
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && (IS_RESIZABLE(wwin) || IS_MOVABLE(wwin))) {
			CloseWindowMenu(scr);

			wKeyboardMoveResizeWindow(wwin);
		}
		break;
	case WKBD_CLOSE:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin) && !WFLAGP(wwin, no_closable)) {
			CloseWindowMenu(scr);
			if (wwin->protocols.DELETE_WINDOW)
				wClientSendProtocol(wwin, w_global.atom.wm.delete_window, event->xkey.time);
		}
		break;
	case WKBD_SELECT:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin)) {
			wSelectWindow(wwin, !wwin->flags.selected);
		}
		break;

	case WKBD_WORKSPACEMAP:
		if (wPreferences.enable_workspace_pager)
			StartWorkspaceMap(scr);
		break;

	case WKBD_FOCUSNEXT:
		StartWindozeCycle(wwin, event, True, False);
		break;

	case WKBD_FOCUSPREV:
		StartWindozeCycle(wwin, event, False, False);
		break;

	case WKBD_GROUPNEXT:
		StartWindozeCycle(wwin, event, True, True);
		break;

	case WKBD_GROUPPREV:
		StartWindozeCycle(wwin, event, False, True);
		break;

	case WKBD_WORKSPACE1 ... WKBD_WORKSPACE10:
		widx = command - WKBD_WORKSPACE1;
		i = (scr->current_workspace / 10) * 10 + widx;
		if (wPreferences.ws_advance || i < scr->workspace_count)
			wWorkspaceChange(scr, i);
		break;

	case WKBD_NEXTWORKSPACE:
		wWorkspaceRelativeChange(scr, 1);
		break;
	case WKBD_PREVWORKSPACE:
		wWorkspaceRelativeChange(scr, -1);
		break;
	case WKBD_LASTWORKSPACE:
		wWorkspaceChange(scr, scr->last_workspace);
		break;

	case WKBD_MOVE_WORKSPACE1 ... WKBD_MOVE_WORKSPACE10:
		widx = command - WKBD_MOVE_WORKSPACE1;
		i = (scr->current_workspace / 10) * 10 + widx;
		if (wwin && (wPreferences.ws_advance || i < scr->workspace_count))
			wWindowChangeWorkspace(wwin, i);
		break;

	case WKBD_MOVE_NEXTWORKSPACE:
		if (wwin)
			wWindowChangeWorkspaceRelative(wwin, 1);
		break;
	case WKBD_MOVE_PREVWORKSPACE:
		if (wwin)
			wWindowChangeWorkspaceRelative(wwin, -1);
		break;
	case WKBD_MOVE_LASTWORKSPACE:
		if (wwin)
			wWindowChangeWorkspace(wwin, scr->last_workspace);
		break;

	case WKBD_MOVE_NEXTWSLAYER:
	case WKBD_MOVE_PREVWSLAYER:
		{
			if (wwin) {
				int row, column;

				row = scr->current_workspace / 10;
				column = scr->current_workspace % 10;

				if (command == WKBD_MOVE_NEXTWSLAYER) {
					if ((row + 1) * 10 < scr->workspace_count)
						wWindowChangeWorkspace(wwin, column + (row + 1) * 10);
				} else {
					if (row > 0)
						wWindowChangeWorkspace(wwin, column + (row - 1) * 10);
				}
			}
		}
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

		widx = command - WKBD_WINDOW1;

		if (scr->shortcutWindows[widx]) {
			WMArray *list = scr->shortcutWindows[widx];
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
			if (scr->shortcutWindows[widx]) {
				WMFreeArray(scr->shortcutWindows[widx]);
				scr->shortcutWindows[widx] = NULL;
			}

			if (wwin->flags.selected && scr->selected_windows) {
				scr->shortcutWindows[widx] = WMDuplicateArray(scr->selected_windows);
				/*WMRemoveFromArray(scr->shortcutWindows[index], wwin);
				   WMInsertInArray(scr->shortcutWindows[index], 0, wwin); */
			} else {
				scr->shortcutWindows[widx] = WMCreateArray(4);
				WMAddToArray(scr->shortcutWindows[widx], wwin);
			}

			wSelectWindow(wwin, !wwin->flags.selected);
			XFlush(dpy);
			wusleep(3000);
			wSelectWindow(wwin, !wwin->flags.selected);
			XFlush(dpy);

		} else if (scr->selected_windows && WMGetArrayItemCount(scr->selected_windows)) {

			if (wwin->flags.selected && scr->selected_windows) {
				if (scr->shortcutWindows[widx]) {
					WMFreeArray(scr->shortcutWindows[widx]);
				}
				scr->shortcutWindows[widx] = WMDuplicateArray(scr->selected_windows);
			}
		}

		break;

	case WKBD_RELAUNCH:
		if (ISMAPPED(wwin) && ISFOCUSED(wwin))
			(void) RelaunchWindow(wwin);

		break;

	case WKBD_SWITCH_SCREEN:
		if (w_global.screen_count > 1) {
			WScreen *scr2;
			int i;

			/* find index of this screen */
			for (i = 0; i < w_global.screen_count; i++) {
				if (wScreenWithNumber(i) == scr)
					break;
			}
			i++;
			if (i >= w_global.screen_count) {
				i = 0;
			}
			scr2 = wScreenWithNumber(i);

			if (scr2) {
				XWarpPointer(dpy, scr->root_win, scr2->root_win, 0, 0, 0, 0,
					     scr2->scr_width / 2, scr2->scr_height / 2);
			}
		}
		break;

	case WKBD_RUN:
	{
		char *cmdline;

		cmdline = ExpandOptions(scr, _("exec %A(Run,Type command to run:)"));

		if (cmdline) {
			XGrabPointer(dpy, scr->root_win, True, 0,
			     GrabModeAsync, GrabModeAsync, None, wPreferences.cursor[WCUR_WAIT], CurrentTime);
			XSync(dpy, False);

			ExecuteShellCommand(scr, cmdline);
			wfree(cmdline);

			XUngrabPointer(dpy, CurrentTime);
			XSync(dpy, False);
		}
		break;
	}

	case WKBD_NEXTWSLAYER:
	case WKBD_PREVWSLAYER:
		{
			int row, column;

			row = scr->current_workspace / 10;
			column = scr->current_workspace % 10;

			if (command == WKBD_NEXTWSLAYER) {
				if ((row + 1) * 10 < scr->workspace_count)
					wWorkspaceChange(scr, column + (row + 1) * 10);
			} else {
				if (row > 0)
					wWorkspaceChange(scr, column + (row - 1) * 10);
			}
		}
		break;
	case WKBD_CLIPRAISELOWER:
		if (!wPreferences.flags.noclip)
			wDockRaiseLower(scr->workspaces[scr->current_workspace]->clip);
		break;
	case WKBD_DOCKRAISELOWER:
		if (!wPreferences.flags.nodock)
			wDockRaiseLower(scr->dock);
		break;
#ifdef KEEP_XKB_LOCK_STATUS
	case WKBD_TOGGLE:
		if (wPreferences.modelock) {
			/*toggle */
			wwin = scr->focused_window;

			if (wwin && wwin->flags.mapped
			    && wwin->frame->workspace == wwin->screen_ptr->current_workspace
			    && !wwin->flags.miniaturized && !wwin->flags.hidden) {
				XkbGetState(dpy, XkbUseCoreKbd, &staterec);

				wwin->frame->languagemode = wwin->frame->last_languagemode;
				wwin->frame->last_languagemode = staterec.group;
				XkbLockGroup(dpy, XkbUseCoreKbd, wwin->frame->languagemode);

			}
		}
		break;
#endif	/* KEEP_XKB_LOCK_STATUS */
	}
}
#ifdef NEXTSPACE
static void handleKeyRelease(XEvent * event)
{
	WScreen *scr = wScreenForRootWindow(event->xkey.root);
	WWindow *wwin = scr->focused_window;
  
  if (event->xkey.window == event->xkey.root ||
      event->xkey.window == scr->no_focus_win) {
    return;
  }
  /* fprintf(stderr, "[WindowMaker] handleKeyRelease: %i state: %i mask: %i\n", */
  /*         event->xkey.keycode, event->xkey.state, MOD_MASK); */
	if ( (event->xkey.keycode == XKeysymToKeycode(dpy, XK_Super_L)) ||
       (event->xkey.keycode == XKeysymToKeycode(dpy, XK_Super_R)) ) {
    if (wwin) {
      scr->flags.modifier_pressed = 0;
      wWindowUpdateButtonImages(wwin);
      if (wwin->flags.is_gnustep) {
        XSendEvent(dpy, scr->focused_window->client_win, True, KeyRelease, event);
      }
    }
  }
}
#endif
static void handleMotionNotify(XEvent * event)
{
	WScreen *scr = wScreenForRootWindow(event->xmotion.root);

#ifdef NEXTSPACE
	WWindow *wwin = wWindowFor(event->xmotion.window);

	if (event->xmotion.state == 0 || wwin == NULL) {
		return;
	}

	if (event->xmotion.state & Button1Mask &&
			XGrabPointer(dpy, event->xmotion.window, False,
									ButtonMotionMask | ButtonReleaseMask | ButtonPressMask,
									GrabModeAsync, GrabModeAsync, None, None, CurrentTime) == GrabSuccess) {
		/* wMouseMoveWindow checks for button on ButtonRelease event inside it's loop */
		event->xbutton.button = Button1;
		if (event->xmotion.window == wwin->frame->titlebar->window ||
				event->xmotion.state & MOD_MASK) {
			/* move the window */
			wMouseMoveWindow(wwin, event);
		}
		else if (IS_RESIZABLE(wwin) && event->xmotion.window == wwin->frame->resizebar->window) {
			wMouseResizeWindow(wwin, event);
		}
		XUngrabPointer(dpy, CurrentTime);
	}
#endif

	if (wPreferences.scrollable_menus) {
		WMPoint p = wmkpoint(event->xmotion.x_root, event->xmotion.y_root);
		WMRect rect = wGetRectForHead(scr, wGetHeadForPoint(scr, p));

		if (scr->flags.jump_back_pending ||
		    p.x <= (rect.pos.x + 1) ||
		    p.x >= (rect.pos.x + rect.size.width - 2) ||
		    p.y <= (rect.pos.y + 1) || p.y >= (rect.pos.y + rect.size.height - 2)) {
			WMenu *menu;

			menu = wMenuUnderPointer(scr);
			if (menu != NULL)
				wMenuScroll(menu);
		}
	}
}

static void handleVisibilityNotify(XEvent * event)
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
		static const long icccm_version[] = { 2, 0 };

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
		notify.property = (event->property == None)?(event->target):(event->property);

		XChangeProperty(dpy, event->requestor, notify.property,
		                XA_INTEGER, 32, PropModeReplace,
		                (unsigned char *) icccm_version, wlengthof(icccm_version));
	}

 not_our_selection:
	if (notify.property == None)
		wwarning("received SelectionRequest(%s) for target=\"%s\" from requestor 0x%lX but we have no answer",
		         XGetAtomName(dpy, event->selection), XGetAtomName(dpy, event->target), (long) event->requestor);

	/* Send the answer to the requestor */
	XSendEvent(dpy, event->requestor, False, 0L, (XEvent *) &notify);

#else
	/*
	 * If the support for ICCCM window manager replacement was not enabled, we should not receive
	 * this kind of event, so we just ignore it (Conceptually, we should reply with 'SelectionNotify'
	 * event with property set to 'None' to tell that we don't have this selection, but that is a bit
	 * costly for an event that shall never happen).
	 */
	(void) event;
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

	wmessage(_("another window manager is replacing us!"));
	Shutdown(WSExitMode);
#else
	/*
	 * If the support for ICCCM window manager replacement was not enabled, we should not receive
	 * this kind of event, so we simply do nothing.
	 */
	(void) event;
#endif
}
