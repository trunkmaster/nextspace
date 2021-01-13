/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
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

#ifndef __WORKSPACE_WM_WEVENT__
#define __WORKSPACE_WM_WEVENT__

#include <CoreFoundation/CFRunLoop.h>

#include "wview.h"

/* -- Event handlers -- */

#define ClientMessageMask	(1L<<30)

typedef void WMEventProc(XEvent *event, void *clientData);
typedef void WMEventHook(XEvent *event);

typedef struct W_EventHandler {
  unsigned long eventMask;

  WMEventProc *proc;

  void *clientData;
} W_EventHandler;

void W_CallDestroyHandlers(W_View *view);

WMEventHook* WMHookEventHandler(WMEventHook *handler);

void WMCreateEventHandler(WMView *view, unsigned long mask,
                          WMEventProc *eventProc, void *clientData);

void WMDeleteEventHandler(WMView *view, unsigned long mask,
                          WMEventProc *eventProc, void *clientData);

int WMHandleEvent(XEvent *event);

void WMNextEvent(Display *dpy, XEvent *event);

void WMMaskEvent(Display *dpy, long mask, XEvent *event);

/* -- Timers -- */

CFRunLoopTimerRef WMAddTimerHandler(CFTimeInterval fireTimeout,
                                    CFTimeInterval interval,
                                    CFRunLoopTimerCallBack callback,
                                    void *cdata);
void WMDeleteTimerHandler(CFRunLoopTimerRef timer);

#endif /* __WORKSPACE_WM_WEVENT__ */
