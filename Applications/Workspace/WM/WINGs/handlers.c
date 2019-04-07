
/*
 * WINGs internal handlers: timer, idle and input handlers
 */

#include "wconfig.h"
#include "WINGsP.h"

#include <sys/types.h>
#include <unistd.h>

#include <X11/Xos.h>

#ifdef HAVE_SYS_SELECT_H
# include <sys/select.h>
#endif

#include <time.h>

#ifndef X_GETTIMEOFDAY
#define X_GETTIMEOFDAY(t) gettimeofday(t, (struct timezone*)0)
#endif

typedef struct TimerHandler {
	WMCallback *callback;	/* procedure to call */
	struct timeval when;	/* when to call the callback */
	void *clientData;
	struct TimerHandler *next;
	int nextDelay;		/* 0 if it's one-shot */
} TimerHandler;

typedef struct IdleHandler {
	WMCallback *callback;
	void *clientData;
} IdleHandler;

typedef struct InputHandler {
	WMInputProc *callback;
	void *clientData;
	int fd;
	int mask;
} InputHandler;

/* queue of timer event handlers */
static TimerHandler *timerHandler = NULL;

static WMArray *idleHandler = NULL;

static WMArray *inputHandler = NULL;

#define timerPending()	(timerHandler)

static void rightNow(struct timeval *tv)
{
	X_GETTIMEOFDAY(tv);
}

/* is t1 after t2 ? */
#define IS_AFTER(t1, t2)	(((t1).tv_sec > (t2).tv_sec) || \
    (((t1).tv_sec == (t2).tv_sec) \
    && ((t1).tv_usec > (t2).tv_usec)))

#define IS_ZERO(tv) (tv.tv_sec == 0 && tv.tv_usec == 0)

#define SET_ZERO(tv) tv.tv_sec = 0, tv.tv_usec = 0

static void addmillisecs(struct timeval *tv, int milliseconds)
{
	tv->tv_usec += milliseconds * 1000;

	tv->tv_sec += tv->tv_usec / 1000000;
	tv->tv_usec = tv->tv_usec % 1000000;
}

static void enqueueTimerHandler(TimerHandler * handler)
{
	TimerHandler *tmp;

	/* insert callback in queue, sorted by time left */
	if (!timerHandler || !IS_AFTER(handler->when, timerHandler->when)) {
		/* first in the queue */
		handler->next = timerHandler;
		timerHandler = handler;
	} else {
		tmp = timerHandler;
		while (tmp->next && IS_AFTER(handler->when, tmp->next->when)) {
			tmp = tmp->next;
		}
		handler->next = tmp->next;
		tmp->next = handler;
	}
}

static void delayUntilNextTimerEvent(struct timeval *delay)
{
	struct timeval now;
	TimerHandler *handler;

	handler = timerHandler;
	while (handler && IS_ZERO(handler->when))
		handler = handler->next;

	if (!handler) {
		/* The return value of this function is only valid if there _are_
		   timers active. */
		delay->tv_sec = 0;
		delay->tv_usec = 0;
		return;
	}

	rightNow(&now);
	if (IS_AFTER(now, handler->when)) {
		delay->tv_sec = 0;
		delay->tv_usec = 0;
	} else {
		delay->tv_sec = handler->when.tv_sec - now.tv_sec;
		delay->tv_usec = handler->when.tv_usec - now.tv_usec;
		if (delay->tv_usec < 0) {
			delay->tv_usec += 1000000;
			delay->tv_sec--;
		}
	}
}

WMHandlerID WMAddTimerHandler(int milliseconds, WMCallback * callback, void *cdata)
{
	TimerHandler *handler;

	handler = malloc(sizeof(TimerHandler));
	if (!handler)
		return NULL;

	rightNow(&handler->when);
	addmillisecs(&handler->when, milliseconds);
	handler->callback = callback;
	handler->clientData = cdata;
	handler->nextDelay = 0;

	enqueueTimerHandler(handler);

	return handler;
}

WMHandlerID WMAddPersistentTimerHandler(int milliseconds, WMCallback * callback, void *cdata)
{
	TimerHandler *handler = WMAddTimerHandler(milliseconds, callback, cdata);

	if (handler != NULL)
		handler->nextDelay = milliseconds;

	return handler;
}

void WMDeleteTimerWithClientData(void *cdata)
{
	TimerHandler *handler, *tmp;

	if (!cdata || !timerHandler)
		return;

	tmp = timerHandler;
	if (tmp->clientData == cdata) {
		tmp->nextDelay = 0;
		if (!IS_ZERO(tmp->when)) {
			timerHandler = tmp->next;
			wfree(tmp);
		}
	} else {
		while (tmp->next) {
			if (tmp->next->clientData == cdata) {
				handler = tmp->next;
				handler->nextDelay = 0;
				if (IS_ZERO(handler->when))
					break;
				tmp->next = handler->next;
				wfree(handler);
				break;
			}
			tmp = tmp->next;
		}
	}
}

void WMDeleteTimerHandler(WMHandlerID handlerID)
{
	TimerHandler *tmp, *handler = (TimerHandler *) handlerID;

	if (!handler || !timerHandler)
		return;

	tmp = timerHandler;

	handler->nextDelay = 0;

	if (IS_ZERO(handler->when))
		return;

	if (tmp == handler) {
		timerHandler = handler->next;
		wfree(handler);
	} else {
		while (tmp->next) {
			if (tmp->next == handler) {
				tmp->next = handler->next;
				wfree(handler);
				break;
			}
			tmp = tmp->next;
		}
	}
}

WMHandlerID WMAddIdleHandler(WMCallback * callback, void *cdata)
{
	IdleHandler *handler;

	handler = malloc(sizeof(IdleHandler));
	if (!handler)
		return NULL;

	handler->callback = callback;
	handler->clientData = cdata;
	/* add handler at end of queue */
	if (!idleHandler) {
		idleHandler = WMCreateArrayWithDestructor(16, wfree);
	}
	WMAddToArray(idleHandler, handler);

	return handler;
}

void WMDeleteIdleHandler(WMHandlerID handlerID)
{
	IdleHandler *handler = (IdleHandler *) handlerID;

	if (!handler || !idleHandler)
		return;

	WMRemoveFromArray(idleHandler, handler);
}

WMHandlerID WMAddInputHandler(int fd, int condition, WMInputProc * proc, void *clientData)
{
	InputHandler *handler;

	handler = wmalloc(sizeof(InputHandler));

	handler->fd = fd;
	handler->mask = condition;
	handler->callback = proc;
	handler->clientData = clientData;

	if (!inputHandler)
		inputHandler = WMCreateArrayWithDestructor(16, wfree);
	WMAddToArray(inputHandler, handler);

	return handler;
}

void WMDeleteInputHandler(WMHandlerID handlerID)
{
	InputHandler *handler = (InputHandler *) handlerID;

	if (!handler || !inputHandler)
		return;

	WMRemoveFromArray(inputHandler, handler);
}

Bool W_CheckIdleHandlers(void)
{
	IdleHandler *handler;
	WMArray *handlerCopy;
	WMArrayIterator iter;

	if (!idleHandler || WMGetArrayItemCount(idleHandler) == 0) {
		W_FlushIdleNotificationQueue();
		/* make sure an observer in queue didn't added an idle handler */
		return (idleHandler != NULL && WMGetArrayItemCount(idleHandler) > 0);
	}

	handlerCopy = WMDuplicateArray(idleHandler);

	WM_ITERATE_ARRAY(handlerCopy, handler, iter) {
		/* check if the handler still exist or was removed by a callback */
		if (WMGetFirstInArray(idleHandler, handler) == WANotFound)
			continue;

		(*handler->callback) (handler->clientData);
		WMDeleteIdleHandler(handler);
	}

	WMFreeArray(handlerCopy);

	W_FlushIdleNotificationQueue();

	/* this is not necesarrily False, because one handler can re-add itself */
	return (WMGetArrayItemCount(idleHandler) > 0);
}

void W_CheckTimerHandlers(void)
{
	TimerHandler *handler;
	struct timeval now;

	if (!timerHandler) {
		W_FlushASAPNotificationQueue();
		return;
	}

	rightNow(&now);

	handler = timerHandler;
	while (handler && IS_AFTER(now, handler->when)) {
		if (!IS_ZERO(handler->when)) {
			SET_ZERO(handler->when);
			(*handler->callback) (handler->clientData);
		}
		handler = handler->next;
	}

	while (timerHandler && IS_ZERO(timerHandler->when)) {
		handler = timerHandler;
		timerHandler = timerHandler->next;

		if (handler->nextDelay > 0) {
			handler->when = now;
			addmillisecs(&handler->when, handler->nextDelay);
			enqueueTimerHandler(handler);
		} else {
			wfree(handler);
		}
	}

	W_FlushASAPNotificationQueue();
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
 *
 */
Bool W_HandleInputEvents(Bool waitForInput, int inputfd)
{
#if defined(HAVE_POLL) && defined(HAVE_POLL_H) && !defined(HAVE_SELECT)
	struct poll fd *fds;
	InputHandler *handler;
	int count, timeout, nfds, i, extrafd;

	extrafd = (inputfd < 0) ? 0 : 1;

	if (inputHandler)
		nfds = WMGetArrayItemCount(inputHandler);
	else
		nfds = 0;

	if (!extrafd && nfds == 0) {
		W_FlushASAPNotificationQueue();
		return False;
	}

	fds = wmalloc((nfds + extrafd) * sizeof(struct pollfd));
	if (extrafd) {
		/* put this to the end of array to avoid using ranges from 1 to nfds+1 */
		fds[nfds].fd = inputfd;
		fds[nfds].events = POLLIN;
	}

	/* use WM_ITERATE_ARRAY() here */
	for (i = 0; i < nfds; i++) {
		handler = WMGetFromArray(inputHandler, i);
		fds[i].fd = handler->fd;
		fds[i].events = 0;
		if (handler->mask & WIReadMask)
			fds[i].events |= POLLIN;

		if (handler->mask & WIWriteMask)
			fds[i].events |= POLLOUT;

#if 0				/* FIXME */
		if (handler->mask & WIExceptMask)
			FD_SET(handler->fd, &eset);
#endif
	}

	/*
	 * Setup the timeout to the estimated time until the
	 * next timer expires.
	 */
	if (!waitForInput) {
		timeout = 0;
	} else if (timerPending()) {
		struct timeval tv;
		delayUntilNextTimerEvent(&tv);
		timeout = tv.tv_sec * 1000 + tv.tv_usec / 1000;
	} else {
		timeout = -1;
	}

	count = poll(fds, nfds + extrafd, timeout);

	if (count > 0 && nfds > 0) {
		WMArray *handlerCopy = WMDuplicateArray(inputHandler);
		int mask;

		/* use WM_ITERATE_ARRAY() here */
		for (i = 0; i < nfds; i++) {
			handler = WMGetFromArray(handlerCopy, i);
			/* check if the handler still exist or was removed by a callback */
			if (WMGetFirstInArray(inputHandler, handler) == WANotFound)
				continue;

			mask = 0;

			if ((handler->mask & WIReadMask) &&
			    (fds[i].revents & (POLLIN | POLLRDNORM | POLLRDBAND | POLLPRI)))
				mask |= WIReadMask;

			if ((handler->mask & WIWriteMask) && (fds[i].revents & (POLLOUT | POLLWRBAND)))
				mask |= WIWriteMask;

			if ((handler->mask & WIExceptMask) && (fds[i].revents & (POLLHUP | POLLNVAL | POLLERR)))
				mask |= WIExceptMask;

			if (mask != 0 && handler->callback) {
				(*handler->callback) (handler->fd, mask, handler->clientData);
			}
		}

		WMFreeArray(handlerCopy);
	}

	wfree(fds);

	W_FlushASAPNotificationQueue();

	return (count > 0);
#else
#ifdef HAVE_SELECT
	struct timeval timeout;
	struct timeval *timeoutPtr;
	fd_set rset, wset, eset;
	int maxfd, nfds, i;
	int count;
	InputHandler *handler;

	if (inputHandler)
		nfds = WMGetArrayItemCount(inputHandler);
	else
		nfds = 0;

	if (inputfd < 0 && nfds == 0) {
		W_FlushASAPNotificationQueue();
		return False;
	}

	FD_ZERO(&rset);
	FD_ZERO(&wset);
	FD_ZERO(&eset);

	if (inputfd < 0) {
		maxfd = 0;
	} else {
		FD_SET(inputfd, &rset);
		maxfd = inputfd;
	}

	/* use WM_ITERATE_ARRAY() here */
	for (i = 0; i < nfds; i++) {
		handler = WMGetFromArray(inputHandler, i);
		if (handler->mask & WIReadMask)
			FD_SET(handler->fd, &rset);

		if (handler->mask & WIWriteMask)
			FD_SET(handler->fd, &wset);

		if (handler->mask & WIExceptMask)
			FD_SET(handler->fd, &eset);

		if (maxfd < handler->fd)
			maxfd = handler->fd;
	}

	/*
	 * Setup the timeout to the estimated time until the
	 * next timer expires.
	 */
	if (!waitForInput) {
		SET_ZERO(timeout);
		timeoutPtr = &timeout;
	} else if (timerPending()) {
		delayUntilNextTimerEvent(&timeout);
		timeoutPtr = &timeout;
	} else {
		timeoutPtr = (struct timeval *)0;
	}

	count = select(1 + maxfd, &rset, &wset, &eset, timeoutPtr);

	if (count > 0 && nfds > 0) {
		WMArray *handlerCopy = WMDuplicateArray(inputHandler);
		int mask;

		/* use WM_ITERATE_ARRAY() here */
		for (i = 0; i < nfds; i++) {
			handler = WMGetFromArray(handlerCopy, i);
			/* check if the handler still exist or was removed by a callback */
			if (WMGetFirstInArray(inputHandler, handler) == WANotFound)
				continue;

			mask = 0;

			if ((handler->mask & WIReadMask) && FD_ISSET(handler->fd, &rset))
				mask |= WIReadMask;

			if ((handler->mask & WIWriteMask) && FD_ISSET(handler->fd, &wset))
				mask |= WIWriteMask;

			if ((handler->mask & WIExceptMask) && FD_ISSET(handler->fd, &eset))
				mask |= WIExceptMask;

			if (mask != 0 && handler->callback) {
				(*handler->callback) (handler->fd, mask, handler->clientData);
			}
		}

		WMFreeArray(handlerCopy);
	}

	W_FlushASAPNotificationQueue();

	return (count > 0);
#else				/* not HAVE_SELECT, not HAVE_POLL */
# error   Neither select nor poll. You lose.
#endif				/* HAVE_SELECT */
#endif				/* HAVE_POLL */
}
