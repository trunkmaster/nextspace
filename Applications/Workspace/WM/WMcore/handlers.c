/*
 *WINGs internal handlers: timer, idle and input handlers
 */

#include <sys/types.h>
#include <unistd.h>

#include <X11/Xos.h>

#include <WINGs/WINGs.h>

#include "wconfig.h"

#include "array.h"
#include "memory.h"

#ifdef HAVE_SYS_SELECT_H
# include <sys/select.h>
#endif

#include <time.h>
#include "handlers.h"

#ifndef X_GETTIMEOFDAY
#define X_GETTIMEOFDAY(t) gettimeofday(t, (struct timezone*)0)
#endif

/* typedef struct InputHandler { */
/*   WMInputProc *callback; */
/*   void *clientData; */
/*   int fd; */
/*   int mask; */
/* } InputHandler; */

/* static WMArray *inputHandler = NULL; */

/* #define timerPending()	(timerHandler) */

/* is t1 after t2 ? */
/* #define IS_AFTER(t1, t2)	(((t1).tv_sec > (t2).tv_sec) ||         \ */
/*                                  (((t1).tv_sec == (t2).tv_sec)          \ */
/*                                   && ((t1).tv_usec > (t2).tv_usec))) */

/* #define IS_ZERO(tv) (tv.tv_sec == 0 && tv.tv_usec == 0) */

/* #define SET_ZERO(tv) tv.tv_sec = 0, tv.tv_usec = 0 */

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

/* Bool W_HandleInputEvents(Bool waitForInput, int inputfd) */
/* { */
/* #if defined(HAVE_POLL) && defined(HAVE_POLL_H) && !defined(HAVE_SELECT) */
/*   struct poll fd *fds; */
/*   InputHandler *handler; */
/*   int count, timeout, nfds, i, extrafd; */

/*   extrafd = (inputfd < 0) ? 0 : 1; */

/*   if (inputHandler) */
/*     nfds = WMGetArrayItemCount(inputHandler); */
/*   else */
/*     nfds = 0; */

/*   if (!extrafd && nfds == 0) { */
/*     /\* W_FlushASAPNotificationQueue(); *\/ */
/*     return False; */
/*   } */

/*   fds = wmalloc((nfds + extrafd)* sizeof(struct pollfd)); */
/*   if (extrafd) { */
/*     /\* put this to the end of array to avoid using ranges from 1 to nfds+1 *\/ */
/*     fds[nfds].fd = inputfd; */
/*     fds[nfds].events = POLLIN; */
/*   } */

/*   /\* use WM_ITERATE_ARRAY() here *\/ */
/*   for (i = 0; i < nfds; i++) { */
/*     handler = WMGetFromArray(inputHandler, i); */
/*     fds[i].fd = handler->fd; */
/*     fds[i].events = 0; */
/*     if (handler->mask & WIReadMask) */
/*       fds[i].events |= POLLIN; */

/*     if (handler->mask & WIWriteMask) */
/*       fds[i].events |= POLLOUT; */

/* #if 0				/\* FIXME *\/ */
/*     if (handler->mask & WIExceptMask) */
/*       FD_SET(handler->fd, &eset); */
/* #endif */
/*   } */

/*   /\* */
/*    *Setup the timeout to the estimated time until the */
/*    *next timer expires. */
/*    *\/ */
/*   if (!waitForInput) { */
/*     timeout = 0; */
/*   /\* } else if (timerPending()) { *\/ */
/*   /\*   struct timeval tv; *\/ */
/*   /\*   delayUntilNextTimerEvent(&tv); *\/ */
/*   /\*   timeout = tv.tv_sec* 1000 + tv.tv_usec / 1000; *\/ */
/*   } else { */
/*     timeout = -1; */
/*   } */

/*   count = poll(fds, nfds + extrafd, timeout); */

/*   if (count > 0 && nfds > 0) { */
/*     WMArray *handlerCopy = WMDuplicateArray(inputHandler); */
/*     int mask; */

/*     /\* use WM_ITERATE_ARRAY() here *\/ */
/*     for (i = 0; i < nfds; i++) { */
/*       handler = WMGetFromArray(handlerCopy, i); */
/*       /\* check if the handler still exist or was removed by a callback *\/ */
/*       if (WMGetFirstInArray(inputHandler, handler) == WANotFound) */
/*         continue; */

/*       mask = 0; */

/*       if ((handler->mask & WIReadMask) && */
/*           (fds[i].revents & (POLLIN | POLLRDNORM | POLLRDBAND | POLLPRI))) */
/*         mask |= WIReadMask; */

/*       if ((handler->mask & WIWriteMask) && (fds[i].revents & (POLLOUT | POLLWRBAND))) */
/*         mask |= WIWriteMask; */

/*       if ((handler->mask & WIExceptMask) && (fds[i].revents & (POLLHUP | POLLNVAL | POLLERR))) */
/*         mask |= WIExceptMask; */

/*       if (mask != 0 && handler->callback) { */
/*         (*handler->callback) (handler->fd, mask, handler->clientData); */
/*       } */
/*     } */

/*     WMFreeArray(handlerCopy); */
/*   } */

/*   wfree(fds); */

/*   /\* W_FlushASAPNotificationQueue(); *\/ */

/*   return (count > 0); */
/* #else */
/* #ifdef HAVE_SELECT */
/*   struct timeval timeout; */
/*   struct timeval *timeoutPtr; */
/*   fd_set rset, wset, eset; */
/*   int maxfd, nfds, i; */
/*   int count; */

/*   if (inputfd < 0) { */
/*     return False; */
/*   } */

/*   FD_ZERO(&rset); */
/*   FD_ZERO(&wset); */
/*   FD_ZERO(&eset); */

/*   FD_SET(inputfd, &rset); */
/*   maxfd = inputfd; */

/*   /\* */
/*    *Setup the timeout to the estimated time until the */
/*    *next timer expires. */
/*    *\/ */
/*   if (!waitForInput) { */
/*     SET_ZERO(timeout); */
/*     timeoutPtr = &timeout; */
/*   /\* } else if (timerPending()) { *\/ */
/*   /\*   delayUntilNextTimerEvent(&timeout); *\/ */
/*   /\*   timeoutPtr = &timeout; *\/ */
/*   } else { */
/*     timeoutPtr = (struct timeval *)0; */
/*   } */

/*   count = select(1 + maxfd, &rset, &wset, &eset, timeoutPtr); */

/*   if (count > 0 && nfds > 0) { */
/*     WMArray *handlerCopy = WMDuplicateArray(inputHandler); */
/*     int mask; */

/*     /\* use WM_ITERATE_ARRAY() here *\/ */
/*     for (i = 0; i < nfds; i++) { */
/*       handler = WMGetFromArray(handlerCopy, i); */
/*       /\* check if the handler still exist or was removed by a callback *\/ */
/*       if (WMGetFirstInArray(inputHandler, handler) == WANotFound) */
/*         continue; */

/*       mask = 0; */

/*       if ((handler->mask & WIReadMask) && FD_ISSET(handler->fd, &rset)) */
/*         mask |= WIReadMask; */

/*       if ((handler->mask & WIWriteMask) && FD_ISSET(handler->fd, &wset)) */
/*         mask |= WIWriteMask; */

/*       if ((handler->mask & WIExceptMask) && FD_ISSET(handler->fd, &eset)) */
/*         mask |= WIExceptMask; */

/*       if (mask != 0 && handler->callback) { */
/*         (*handler->callback) (handler->fd, mask, handler->clientData); */
/*       } */
/*     } */

/*     WMFreeArray(handlerCopy); */
/*   } */

/*   return (count > 0); */
/* #else				/\* not HAVE_SELECT, not HAVE_POLL *\/ */
/* # error   Neither select nor poll. You lose. */
/* #endif				/\* HAVE_SELECT *\/ */
/* #endif				/\* HAVE_POLL *\/ */
/* } */
