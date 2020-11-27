#ifndef _WEVENT_H_
#define _WEVENT_H_

#include <WINGs/WINGs.h>
#include <WINGs/wview.h>

typedef void WMEventProc(XEvent *event, void *clientData);
typedef void WMEventHook(XEvent *event);

typedef struct W_EventHandler {
  unsigned long eventMask;

  WMEventProc *proc;

  void *clientData;
} W_EventHandler;

/* -- Functions -- */

void W_CallDestroyHandlers(W_View *view);

/* ---[ WINGs/wevent.c ]-------------------------------------------------- */

WMEventHook* WMHookEventHandler(WMEventHook *handler);

int WMHandleEvent(XEvent *event);

void WMCreateEventHandler(WMView *view, unsigned long mask,
                          WMEventProc *eventProc, void *clientData);

void WMDeleteEventHandler(WMView *view, unsigned long mask,
                          WMEventProc *eventProc, void *clientData);

/* void WMNextEvent(Display *dpy, XEvent *event); */

void WMMaskEvent(Display *dpy, long mask, XEvent *event);

#endif
