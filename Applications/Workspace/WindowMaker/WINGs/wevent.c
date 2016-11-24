
/*
 * This event handling stuff was inspired on Tk.
 */

#include "WINGsP.h"

/* table to map event types to event masks */
static const unsigned long eventMasks[] = {
	0,
	0,
	KeyPressMask,		/* KeyPress */
	KeyReleaseMask,		/* KeyRelease */
	ButtonPressMask,	/* ButtonPress */
	ButtonReleaseMask,	/* ButtonRelease */
	PointerMotionMask | PointerMotionHintMask | ButtonMotionMask
	    | Button1MotionMask | Button2MotionMask | Button3MotionMask | Button4MotionMask | Button5MotionMask,
	/* MotionNotify */
	EnterWindowMask,	/* EnterNotify */
	LeaveWindowMask,	/* LeaveNotify */
	FocusChangeMask,	/* FocusIn */
	FocusChangeMask,	/* FocusOut */
	KeymapStateMask,	/* KeymapNotify */
	ExposureMask,		/* Expose */
	ExposureMask,		/* GraphicsExpose */
	ExposureMask,		/* NoExpose */
	VisibilityChangeMask,	/* VisibilityNotify */
	SubstructureNotifyMask,	/* CreateNotify */
	StructureNotifyMask,	/* DestroyNotify */
	StructureNotifyMask,	/* UnmapNotify */
	StructureNotifyMask,	/* MapNotify */
	SubstructureRedirectMask,	/* MapRequest */
	StructureNotifyMask,	/* ReparentNotify */
	StructureNotifyMask,	/* ConfigureNotify */
	SubstructureRedirectMask,	/* ConfigureRequest */
	StructureNotifyMask,	/* GravityNotify */
	ResizeRedirectMask,	/* ResizeRequest */
	StructureNotifyMask,	/* CirculateNotify */
	SubstructureRedirectMask,	/* CirculateRequest */
	PropertyChangeMask,	/* PropertyNotify */
	0,			/* SelectionClear */
	0,			/* SelectionRequest */
	0,			/* SelectionNotify */
	ColormapChangeMask,	/* ColormapNotify */
	ClientMessageMask,	/* ClientMessage */
	0,			/* Mapping Notify */
};

/* hook for other toolkits or wmaker process their events */
static WMEventHook *extraEventHandler = NULL;

/*
 * WMCreateEventHandler--
 * 	Create an event handler and put it in the event handler list for the
 * view. If the same callback and clientdata are already used in another
 * handler, the masks are OR'ed.
 *
 */
void WMCreateEventHandler(WMView * view, unsigned long mask, WMEventProc * eventProc, void *clientData)
{
	W_EventHandler *hPtr;
	WMArrayIterator iter;

	WM_ITERATE_ARRAY(view->eventHandlers, hPtr, iter) {
		if (hPtr->clientData == clientData && hPtr->proc == eventProc) {
			hPtr->eventMask |= mask;
			return;
		}
	}

	hPtr = wmalloc(sizeof(W_EventHandler));

	/* select events for window */
	hPtr->eventMask = mask;
	hPtr->proc = eventProc;
	hPtr->clientData = clientData;

	WMAddToArray(view->eventHandlers, hPtr);
}

static int matchHandler(const void *item, const void *cdata)
{
	const W_EventHandler *h1 = item;
	const W_EventHandler *h2 = cdata;

	return ((h1->eventMask == h2->eventMask) &&
			  (h1->proc == h2->proc) &&
			  (h1->clientData == h2->clientData));
}

/*
 * WMDeleteEventHandler--
 * 	Delete event handler matching arguments from windows
 * event handler list.
 *
 */
void WMDeleteEventHandler(WMView * view, unsigned long mask, WMEventProc * eventProc, void *clientData)
{
	W_EventHandler tmp;

	tmp.eventMask = mask;
	tmp.proc = eventProc;
	tmp.clientData = clientData;
	WMRemoveFromArrayMatching(view->eventHandlers, matchHandler, (void *)&tmp);
}

static Time getEventTime(WMScreen * screen, XEvent * event)
{
	switch (event->type) {
	case ButtonPress:
	case ButtonRelease:
		return event->xbutton.time;
	case KeyPress:
	case KeyRelease:
		return event->xkey.time;
	case MotionNotify:
		return event->xmotion.time;
	case EnterNotify:
	case LeaveNotify:
		return event->xcrossing.time;
	case PropertyNotify:
		return event->xproperty.time;
	case SelectionClear:
		return event->xselectionclear.time;
	case SelectionRequest:
		return event->xselectionrequest.time;
	case SelectionNotify:
		return event->xselection.time;
	default:
		return screen->lastEventTime;
	}
}

void W_CallDestroyHandlers(W_View * view)
{
	XEvent event;
	WMArrayIterator iter;
	W_EventHandler *hPtr;

	event.type = DestroyNotify;
	event.xdestroywindow.window = view->window;
	event.xdestroywindow.event = view->window;

	WM_ITERATE_ARRAY(view->eventHandlers, hPtr, iter) {
		if (hPtr->eventMask & StructureNotifyMask) {
			(*hPtr->proc) (&event, hPtr->clientData);
		}
	}
}

void WMSetViewNextResponder(WMView * view, WMView * responder)
{
	/* set the widget to receive keyboard events that aren't handled
	 * by this widget */

	view->nextResponder = responder;
}

void WMRelayToNextResponder(WMView * view, XEvent * event)
{
	unsigned long mask = eventMasks[event->xany.type];

	if (view->nextResponder) {
		WMView *next = view->nextResponder;
		W_EventHandler *hPtr;
		WMArrayIterator iter;

		WM_ITERATE_ARRAY(next->eventHandlers, hPtr, iter) {
			if ((hPtr->eventMask & mask)) {
				(*hPtr->proc) (event, hPtr->clientData);
			}
		}
	}
}

int WMHandleEvent(XEvent * event)
{
	W_EventHandler *hPtr;
	W_View *view, *toplevel;
	unsigned long mask;
	Window window;
	WMArrayIterator iter;

	if (event->type == MappingNotify) {
		XRefreshKeyboardMapping(&event->xmapping);
		return True;
	}

	if (XFilterEvent(event, None) == True) {
		return False;
	}

	mask = eventMasks[event->xany.type];

	window = event->xany.window;

	/* diferentiate SubstructureNotify with StructureNotify */
	if (mask == StructureNotifyMask) {
		if (event->xmap.event != event->xmap.window) {
			mask = SubstructureNotifyMask;
			window = event->xmap.event;
		}
	}
	view = W_GetViewForXWindow(event->xany.display, window);

	if (!view) {
		if (extraEventHandler)
			(extraEventHandler) (event);

		return False;
	}

	view->screen->lastEventTime = getEventTime(view->screen, event);

	toplevel = W_TopLevelOfView(view);

	if (event->type == SelectionNotify || event->type == SelectionClear || event->type == SelectionRequest) {
		/* handle selection related events */
		W_HandleSelectionEvent(event);

	}

	/* if it's a key event, redispatch it to the focused control */
	if (mask & (KeyPressMask | KeyReleaseMask)) {
		W_View *focused = W_FocusedViewOfToplevel(toplevel);

		if (focused) {
			view = focused;
		}
	}

	/* compress Motion events */
	if (event->type == MotionNotify && !view->flags.dontCompressMotion) {
		while (XPending(event->xmotion.display)) {
			XEvent ev;
			XPeekEvent(event->xmotion.display, &ev);
			if (ev.type == MotionNotify
			    && event->xmotion.window == ev.xmotion.window
			    && event->xmotion.subwindow == ev.xmotion.subwindow) {
				/* replace events */
				XNextEvent(event->xmotion.display, event);
			} else
				break;
		}
	}

	/* compress expose events */
	if (event->type == Expose && !view->flags.dontCompressExpose) {
		while (XCheckTypedWindowEvent(event->xexpose.display, view->window, Expose, event)) ;
	}

	if (view->screen->modalLoop && toplevel != view->screen->modalView && !toplevel->flags.worksWhenModal) {
		if (event->type == KeyPress || event->type == KeyRelease
		    || event->type == MotionNotify || event->type == ButtonPress
		    || event->type == ButtonRelease || event->type == FocusIn || event->type == FocusOut) {
			return True;
		}
	}

	/* do balloon stuffs */
	if (event->type == EnterNotify)
		W_BalloonHandleEnterView(view);
	else if (event->type == LeaveNotify)
		W_BalloonHandleLeaveView(view);

	/* This is a hack. It will make the panel be secure while
	 * the event handlers are handled, as some event handler
	 * might destroy the widget. */
	W_RetainView(toplevel);

	WM_ITERATE_ARRAY(view->eventHandlers, hPtr, iter) {
		if ((hPtr->eventMask & mask)) {
			(*hPtr->proc) (event, hPtr->clientData);
		}
	}
#if 0
	/* pass the event to the top level window of the widget */
	/* TODO: change this to a responder chain */
	if (view->parent != NULL) {
		vPtr = view;
		while (vPtr->parent != NULL)
			vPtr = vPtr->parent;

		WM_ITERATE_ARRAY(vPtr->eventHandlers, hPtr, iter) {
			if (hPtr->eventMask & mask) {
				(*hPtr->proc) (event, hPtr->clientData);
			}
		}
	}
#endif
	/* save button click info to track double-clicks */
	if (view->screen->ignoreNextDoubleClick) {
		view->screen->ignoreNextDoubleClick = 0;
	} else {
		if (event->type == ButtonPress) {
			view->screen->lastClickWindow = event->xbutton.window;
			view->screen->lastClickTime = event->xbutton.time;
		}
	}

	if (event->type == ClientMessage) {
		/* must be handled at the end, for such message can destroy the view */
		W_HandleDNDClientMessage(toplevel, &event->xclient);
	}

	W_ReleaseView(toplevel);

	return True;
}

int WMIsDoubleClick(XEvent * event)
{
	W_View *view;

	if (event->type != ButtonPress)
		return False;

	view = W_GetViewForXWindow(event->xany.display, event->xbutton.window);

	if (!view)
		return False;

	if (view->screen->lastClickWindow != event->xbutton.window)
		return False;

	if (event->xbutton.time - view->screen->lastClickTime < WINGsConfiguration.doubleClickDelay) {
		view->screen->lastClickTime = 0;
		view->screen->lastClickWindow = None;
		view->screen->ignoreNextDoubleClick = 1;
		return True;
	} else
		return False;
}

/*
 * Check for X and input events. If X events are present input events will
 * not be checked.
 *
 * Return value: True if a X event is available or any input event was
 *               processed, false otherwise (including return because of
 *               some timer handler expired).
 *
 *  If waitForInput is False, it will just peek for available input and return
 * without processing. Return vaue will be True if input is available.
 *
 *  If waitForInput is True, it will wait until an input event arrives on the
 * registered input handlers and ConnectionNumber(dpy), or will return when
 * a timer handler expires if no input event arrived until then.
 */
static Bool waitForEvent(Display * dpy, unsigned long xeventmask, Bool waitForInput)
{
	XSync(dpy, False);
	if (xeventmask == 0) {
		if (XPending(dpy))
			return True;
	} else {
		XEvent ev;
		if (XCheckMaskEvent(dpy, xeventmask, &ev)) {
			XPutBackEvent(dpy, &ev);
			return True;
		}
	}

	return W_HandleInputEvents(waitForInput, ConnectionNumber(dpy));
}

void WMNextEvent(Display * dpy, XEvent * event)
{
	/* Check any expired timers */
	W_CheckTimerHandlers();

	while (XPending(dpy) == 0) {
		/* Do idle and timer stuff while there are no input or X events */
		while (!waitForEvent(dpy, 0, False) && W_CheckIdleHandlers()) {
			/* dispatch timer events */
			W_CheckTimerHandlers();
		}

		/*
		 * Make sure that new events did not arrive while we were doing
		 * timer/idle stuff. Or we might block forever waiting for
		 * an event that already arrived.
		 */
		/* wait for something to happen or a timer to expire */
		waitForEvent(dpy, 0, True);

		/* Check any expired timers */
		W_CheckTimerHandlers();
	}

	XNextEvent(dpy, event);
}

void WMMaskEvent(Display * dpy, long mask, XEvent * event)
{
	/* Check any expired timers */
	W_CheckTimerHandlers();

	while (!XCheckMaskEvent(dpy, mask, event)) {
		/* Do idle and timer stuff while there are no input or X events */
		while (!waitForEvent(dpy, mask, False) && W_CheckIdleHandlers()) {
			W_CheckTimerHandlers();
		}

		if (XCheckMaskEvent(dpy, mask, event))
			return;

		/* Wait for input on the X connection socket or another input handler */
		waitForEvent(dpy, mask, True);

		/* Check any expired timers */
		W_CheckTimerHandlers();
	}
}

Bool WMScreenPending(WMScreen * scr)
{
	if (XPending(scr->display))
		return True;
	else
		return False;
}

WMEventHook *WMHookEventHandler(WMEventHook * handler)
{
	WMEventHook *oldHandler = extraEventHandler;

	extraEventHandler = handler;

	return oldHandler;
}
