/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
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

/*
 * This event handling stuff was inspired on Tk.
 */

#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFRunLoop.h>
#include "util.h"

#include "WM.h"

#if defined(HAVE_POLL) && defined(HAVE_POLL_H) && !HAVE_SELECT
# include <sys/poll.h>
#endif

#ifdef HAVE_SYS_SELECT_H
# include <sys/select.h>
#endif

#include "wscreen.h"
#include "dragcommon.h"
#include "winputmethod.h"
#include "selection.h"
#include "wballoon.h"

#include "wevent.h"

#ifdef __FreeBSD__
#include <sys/types.h>
#include <sys/time.h>
#include <sys/select.h>
#include <unistd.h>
#endif


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

/* hook for other toolkits or WM process their events */
static WMEventHook *extraEventHandler = NULL;

/*
 * WMCreateEventHandler
 * 	Create an event handler and put it in the event handler list for the
 * view. If the same callback and clientdata are already used in another
 * handler, the masks are OR'ed.
 */
void WMCreateEventHandler(WMView *view, unsigned long mask, WMEventProc *eventProc, void *clientData)
{
  WMEventHandler *hPtr;

  for (int i = 0; i < CFArrayGetCount(view->eventHandlers); i++) {
    hPtr = (WMEventHandler *)CFArrayGetValueAtIndex(view->eventHandlers, i);
    if (hPtr->clientData == clientData && hPtr->proc == eventProc) {
      hPtr->eventMask |= mask;
      return;
    }
  }

  hPtr = wmalloc(sizeof(WMEventHandler));

  /* select events for window */
  hPtr->eventMask = mask;
  hPtr->proc = eventProc;
  hPtr->clientData = clientData;

  CFArrayAppendValue(view->eventHandlers, hPtr);
}

/*
 * WMDeleteEventHandler
 *	Delete event handler matching arguments from windows
 * event handler list.
 */
void WMDeleteEventHandler(WMView *view, unsigned long mask, WMEventProc *eventProc, void *clientData)
{
  WMEventHandler tmp;
  WMEventHandler *tmp1;
  WMEventHandler *tmp2;

  tmp.eventMask = mask;
  tmp.proc = eventProc;
  tmp.clientData = clientData;
  tmp1 = &tmp;
  
  for (int i = 0; i < CFArrayGetCount(view->eventHandlers); i++) {
    tmp2 = (WMEventHandler *)CFArrayGetValueAtIndex(view->eventHandlers, i);
    if (((tmp1->eventMask == tmp2->eventMask) &&
         (tmp1->proc == tmp2->proc) &&
         (tmp1->clientData == tmp2->clientData))) {
      CFArrayRemoveValueAtIndex(view->eventHandlers, i);
      break;
    }
  }
}

static Time _getEventTime(WMScreen *screen, XEvent *event)
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

void WMCallDestroyHandlers(WMView *view)
{
  XEvent event;
  WMEventHandler *hPtr;

  event.type = DestroyNotify;
  event.xdestroywindow.window = view->window;
  event.xdestroywindow.event = view->window;

  for (int i = 0; i < CFArrayGetCount(view->eventHandlers); i++) {
    hPtr = (WMEventHandler *)CFArrayGetValueAtIndex(view->eventHandlers, i);
    if (hPtr->eventMask & StructureNotifyMask) {
      (*hPtr->proc) (&event, hPtr->clientData);
    }
  }
}

int WMHandleEvent(XEvent *event)
{
  WMEventHandler *hPtr;
  WMView *view, *toplevel;
  unsigned long mask;
  Window window;

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
  view = WMGetViewForXWindow(event->xany.display, window);

  if (!view) {
    if (extraEventHandler)
      (extraEventHandler) (event);

    return False;
  }

  view->screen->lastEventTime = _getEventTime(view->screen, event);

  toplevel = WMTopLevelOfView(view);

  if (event->type == SelectionNotify || event->type == SelectionClear || event->type == SelectionRequest) {
    /* handle selection related events */
    WMHandleSelectionEvent(event);

  }

  /* if it's a key event, redispatch it to the focused control */
  if (mask & (KeyPressMask | KeyReleaseMask)) {
    WMView *focused = WMFocusedViewOfToplevel(toplevel);

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
    WMBalloonHandleEnterView(view);
  else if (event->type == LeaveNotify)
    WMBalloonHandleLeaveView(view);

  /* This is a hack. It will make the panel be secure while
   *the event handlers are handled, as some event handler
   *might destroy the widget. */
  WMRetainView(toplevel);

  for (int i = 0; i < CFArrayGetCount(view->eventHandlers); i++) {
    hPtr = (WMEventHandler *)CFArrayGetValueAtIndex(view->eventHandlers, i);
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

    for (int i = 0; i < CFArrayGetCount(view->eventHandlers); i++) {
      hPtr = (WMEventHandler *)CFArrayGetValueAtIndex(view->eventHandlers, i);
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
    WMHandleDNDClientMessage(toplevel, &event->xclient);
  }

  WMReleaseView(toplevel);

  return True;
}


/*
 * This functions will handle input events on all registered file descriptors.
 * Input:
 *    - waitForInput - True if we want the function to wait until an event
 *                     appears on a file descriptor we watch, False if we
 *                     want the function to immediately return if there is
 *                     no data available on the file descriptors we watch.
 *    - inputfd      - Extra input file descriptor to watch for input.
 *                     This is only used when called from wevent.c to watch
 *                     on ConnectionNumber(dpy) to avoid blocking of X events
 *                     if we wait for input from other file handlers.
 * Output:
 *    if waitForInput is False, the function will return False if there are no
 *                     input handlers registered, or if there is no data
 *                     available on the registered ones, and will return True
 *                     if there is at least one input handler that has data
 *                     available.
 *    if waitForInput is True, the function will return False if there are no
 *                     input handlers registered, else it will block until an
 *                     event appears on one of the file descriptors it watches
 *                     and then it will return True.
 *
 * If the retured value is True, the input handlers for the corresponding file
 * descriptors are also called.
 *
 * Parametersshould be passed like this:
 * - from wevent.c:
 *   waitForInput - apropriate value passed by the function who called us
 *   inputfd = ConnectionNumber(dpy)
 * - from wutil.c:
 *   waitForInput - apropriate value passed by the function who called us
 *   inputfd = -1
 */
static Bool _waitForXEvents(Bool waitForInput, int inputfd)
{
#if defined(HAVE_POLL) && defined(HAVE_POLL_H) && !HAVE_SELECT
  struct pollfd fds;
  int count, timeout;

  if (inputfd < 0) {
    return False;
  }

  fds.fd = inputfd;
  fds.events = POLLIN;

  timeout = (!waitForInput) ? 0 : -1;
  count = poll(&fds, 1, timeout);

  return (count > 0);
  
#elif HAVE_SELECT
  struct timeval *timeoutPtr;
  fd_set rset, wset, eset;
  int count;

  if (inputfd < 0) {
    return False;
  }

  FD_ZERO(&rset);
  FD_ZERO(&wset);
  FD_ZERO(&eset);
  
  FD_SET(inputfd, &rset);

  /* Setup the timeout to the estimated time until the
     next timer expires. */
  if (!waitForInput) {
    struct timeval timeout;
    timeout.tv_sec = 0;
    timeout.tv_usec = 0;
    timeoutPtr = &timeout;
  } else {
    timeoutPtr = (struct timeval *)0;
  }

  count = select(1 + inputfd, &rset, &wset, &eset, timeoutPtr);

  return (count > 0);
#else
#error    Neither select() nor poll(). You lose.
#endif				/* HAVE_SELECT */
}

/*
 * Check for X and input events. If X events are present input events will
 * not be checked.
 *
 * Return value: True if a X event is available or any input event was
 *               processed, false otherwise (including return because of
 *               some timer handler expired).
 *
 * If waitForInput is False, it will just peek for available input and return
 * without processing. Return vaue will be True if input is available.
 *
 * If waitForInput is True, it will wait until an input event arrives on the
 * registered input handlers and ConnectionNumber(dpy), or will return when
 * a timer handler expires if no input event arrived until then.
 */
static Bool waitForEvent(Display *dpy, unsigned long xeventmask, Bool waitForInput)
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
  return _waitForXEvents(waitForInput, ConnectionNumber(dpy));
}

void WMNextEvent(Display *dpy, XEvent *event)
{
  while (XPending(dpy) == 0) {
    /* Wait for input on the X connection socket */
    waitForEvent(dpy, 0, True);
  }

  XNextEvent(dpy, event);
}

void WMMaskEvent(Display *dpy, long mask, XEvent *event)
{
  while (!XCheckMaskEvent(dpy, mask, event)) {
    /* Wait for input on the X connection socket */
    waitForEvent(dpy, mask, True);
    
    if (XCheckMaskEvent(dpy, mask, event))
      return;
  }
}

WMEventHook *WMHookEventHandler(WMEventHook *handler)
{
  WMEventHook *oldHandler = extraEventHandler;

  extraEventHandler = handler;

  return oldHandler;
}

/* -- Timers -- */

CFRunLoopTimerRef WMAddTimerHandler(CFTimeInterval fireTimeout,
                                    CFTimeInterval interval,
                                    CFRunLoopTimerCallBack callback,
                                    void *cdata)
{
  CFRunLoopTimerRef timer;
  CFRunLoopTimerContext ctx = {0, cdata, NULL, NULL, 0};
  
  /* CFRunLoopTimerCreate(kCFAllocatorDefault, */
  /*                      CFAbsoluteTime fireDate, */
  /*                      CFTimeInterval interval, -- seconds */
  /*                      CFOptionFlags flags, -- ignored */
  /*                      CFIndex order, -- ignored */
  /*                      CFRunLoopTimerCallBack callout, */
  /*                      CFRunLoopTimerContext *context); */
  timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
                               CFAbsoluteTimeGetCurrent() + (float)fireTimeout/10000,
                               (float)interval/10000, 0, 0, callback, &ctx);
  CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
  CFRelease(timer);
  
  return timer;
}

void WMDeleteTimerHandler(CFRunLoopTimerRef timer)
{
  CFRunLoopRemoveTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
}

