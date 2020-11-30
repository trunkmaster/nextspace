#ifndef _WHANDLERS_H_
#define _WHANDLERS_H_

#include <CoreFoundation/CFRunLoop.h>

#include <WINGs/WINGs.h>

/* Timers */
CFRunLoopTimerRef WMAddTimerHandler(CFTimeInterval fireTimeout,
                                    CFTimeInterval interval,
                                    CFRunLoopTimerCallBack callback,
                                    void *cdata);
void WMDeleteTimerHandler(CFRunLoopTimerRef timer);

/* WMHandlerID WMAddTimerHandler(int milliseconds, WMCallback *callback, */
/*                               void *cdata); */

/* WMHandlerID WMAddPersistentTimerHandler(int milliseconds, WMCallback *callback, */
/*                                         void *cdata); */

/* void WMDeleteTimerWithClientData(void *cdata); */

/* void WMDeleteTimerHandler(WMHandlerID handlerID); */

/* Input event handlers */

/* Bool W_HandleInputEvents(Bool waitForInput, int inputfd); */

/* WMHandlerID WMAddInputHandler(int fd, int condition, WMInputProc *proc, */
/*                               void *clientData); */

/* void WMDeleteInputHandler(WMHandlerID handlerID); */

#endif
