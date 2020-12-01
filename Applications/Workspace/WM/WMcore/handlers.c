/*
 * CFRunLoop timers
 */

#include "handlers.h"

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
