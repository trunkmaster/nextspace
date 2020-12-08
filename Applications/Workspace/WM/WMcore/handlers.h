#ifndef __WORKSPACE_WM_WHANDLERS__
#define __WORKSPACE_WM_WHANDLERS__

#include <CoreFoundation/CFRunLoop.h>

/* Timers */
CFRunLoopTimerRef WMAddTimerHandler(CFTimeInterval fireTimeout,
                                    CFTimeInterval interval,
                                    CFRunLoopTimerCallBack callback,
                                    void *cdata);
void WMDeleteTimerHandler(CFRunLoopTimerRef timer);

#endif
