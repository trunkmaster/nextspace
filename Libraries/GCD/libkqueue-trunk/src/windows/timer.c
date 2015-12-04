/*
 * Copyright (c) 2011 Mark Heily <mark@heily.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include "../common/private.h"

/* Convert milliseconds into negative increments of 100-nanoseconds */
static void
convert_msec_to_filetime(LARGE_INTEGER *dst, intptr_t src)
{
	dst->QuadPart = -((int64_t) src * 1000 * 10);
}

static int
ktimer_delete(struct filter *filt, struct knote *kn)
{

    if (kn->data.handle == NULL || kn->kn_event_whandle == NULL)
        return (0);

	if(!UnregisterWaitEx(kn->kn_event_whandle, INVALID_HANDLE_VALUE)) {
		dbg_lasterror("UnregisterWait()");
		return (-1);
	}

	if (!CancelWaitableTimer(kn->data.handle)) {
		dbg_lasterror("CancelWaitableTimer()");
		return (-1);
	}
	if (!CloseHandle(kn->data.handle)) {
		dbg_lasterror("CloseHandle()");
		return (-1);
	}

	if( !(kn->kev.flags & EV_ONESHOT) )
		knote_release(kn);

	kn->data.handle = NULL;
	return (0);
}

static VOID CALLBACK evfilt_timer_callback(void* param, BOOLEAN fired){
	struct knote* kn;
	struct kqueue* kq;

	if(fired){
		dbg_puts("called, but timer did not fire - this case should never be reached");
		return;
	}

	assert(param);
	kn = (struct knote*)param;

	if(kn->kn_flags & KNFL_KNOTE_DELETED) {
		dbg_puts("knote marked for deletion, skipping event");
		return;
	} else {
		kq = kn->kn_kq;
		assert(kq);

		if (!PostQueuedCompletionStatus(kq->kq_iocp, 1, (ULONG_PTR) 0, (LPOVERLAPPED) kn)) {
			dbg_lasterror("PostQueuedCompletionStatus()");
			return;
			/* FIXME: need more extreme action */
		}
#if DEADWOOD
		evt_signal(kq->kq_loop, EVT_WAKEUP, kn);
#endif
	}
	if(kn->kev.flags & EV_ONESHOT) {
		struct filter* filt;
		if( filter_lookup(&filt, kq, kn->kev.filter) )
			dbg_perror("filter_lookup()");
		knote_release(kn);
	}
}

int
evfilt_timer_init(struct filter *filt)
{
    return (0);
}

void
evfilt_timer_destroy(struct filter *filt)
{
}

int
evfilt_timer_copyout(struct kevent* dst, struct knote* src, void* ptr)
{
    memcpy(dst, &src->kev, sizeof(struct kevent));
	// TODO: Timer error handling
	
    /* We have no way to determine the number of times
       the timer triggered, thus we assume it was only once
    */
    dst->data = 1;

	return (0);
}

int
evfilt_timer_knote_create(struct filter *filt, struct knote *kn)
{
    HANDLE th;
	LARGE_INTEGER liDueTime;

    kn->kev.flags |= EV_CLEAR;

    th = CreateWaitableTimer(NULL, FALSE, NULL);
    if (th == NULL) {
        dbg_lasterror("CreateWaitableTimer()");
        return (-1);
    }
    dbg_printf("created timer handle %p", th);

    convert_msec_to_filetime(&liDueTime, kn->kev.data);
	
	// XXX-FIXME add completion routine to this call
    if (!SetWaitableTimer(th, &liDueTime, (LONG)( (kn->kev.flags & EV_ONESHOT) ? 0 : kn->kev.data ), NULL, NULL, FALSE)) {
        dbg_lasterror("SetWaitableTimer()");
        CloseHandle(th);
        return (-1);
    }

    kn->data.handle = th;
	RegisterWaitForSingleObject(&kn->kn_event_whandle, th, evfilt_timer_callback, kn, INFINITE, 0);
	knote_retain(kn);

    return (0);
}

int
evfilt_timer_knote_modify(struct filter *filt, struct knote *kn, 
        const struct kevent *kev)
{
    return (0); /* STUB */
}

int
evfilt_timer_knote_delete(struct filter *filt, struct knote *kn)
{
    return (ktimer_delete(filt,kn));
}

int
evfilt_timer_knote_enable(struct filter *filt, struct knote *kn)
{
    return evfilt_timer_knote_create(filt, kn);
}

int
evfilt_timer_knote_disable(struct filter *filt, struct knote *kn)
{
    return evfilt_timer_knote_delete(filt, kn);
}

const struct filter evfilt_timer = {
    EVFILT_TIMER,
    evfilt_timer_init,
    evfilt_timer_destroy,
    evfilt_timer_copyout,
    evfilt_timer_knote_create,
    evfilt_timer_knote_modify,
    evfilt_timer_knote_delete,
    evfilt_timer_knote_enable,
    evfilt_timer_knote_disable,     
};
