#ifndef _WEVENT_H_
#define _WEVENT_H_

#include <WINGs/wview.h>

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

Bool WMScreenPending(WMScreen *scr);

void WMCreateEventHandler(WMView *view, unsigned long mask,
                          WMEventProc *eventProc, void *clientData);

void WMDeleteEventHandler(WMView *view, unsigned long mask,
                          WMEventProc *eventProc, void *clientData);

int WMIsDoubleClick(XEvent *event);

/*int WMIsTripleClick(XEvent *event);*/

void WMNextEvent(Display *dpy, XEvent *event);

void WMMaskEvent(Display *dpy, long mask, XEvent *event);

void WMSetViewNextResponder(WMView *view, WMView *responder);

void WMRelayToNextResponder(WMView *view, XEvent *event);

#endif
