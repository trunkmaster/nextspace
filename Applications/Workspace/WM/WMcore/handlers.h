#ifndef _WHANDLERS_H_
#define _WHANDLERS_H_

#include <CoreFoundation/CFRunLoop.h>

/* Timers */
CFRunLoopTimerRef WMAddTimerHandler(CFTimeInterval fireTimeout,
                                    CFTimeInterval interval,
                                    CFRunLoopTimerCallBack callback,
                                    void *cdata);
void WMDeleteTimerHandler(CFRunLoopTimerRef timer);

#endif
