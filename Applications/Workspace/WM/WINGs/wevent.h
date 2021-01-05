#ifndef __WORKSPACE_WM_WEVENT__
#define __WORKSPACE_WM_WEVENT__

#include <CoreFoundation/CFRunLoop.h>

#include <WINGs/wview.h>

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

#endif
