/*
 * Copyright (c) 2009 Mark Heily <mark@heily.com>
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

int
evfilt_user_init(struct filter *filt)
{
    return (0);
}

void
evfilt_user_destroy(struct filter *filt)
{
}

int
evfilt_user_copyout(struct kevent* dst, struct knote* src, void* ptr)
{
    memcpy(dst, &src->kev, sizeof(struct kevent));
	
    dst->fflags &= ~NOTE_FFCTRLMASK;     //FIXME: Not sure if needed
    dst->fflags &= ~NOTE_TRIGGER;
    if (src->kev.flags & EV_ADD) {
        /* NOTE: True on FreeBSD but not consistent behavior with
           other filters. */
        dst->flags &= ~EV_ADD;
    }
    if (src->kev.flags & EV_CLEAR)
        src->kev.fflags &= ~NOTE_TRIGGER;

    if (src->kev.flags & EV_DISPATCH)
        src->kev.fflags &= ~NOTE_TRIGGER;

	return (0);
}

int
evfilt_user_knote_create(struct filter *filt, struct knote *kn)
{
	return (0);
}

int
evfilt_user_knote_modify(struct filter *filt, struct knote *kn, 
        const struct kevent *kev)
{
    unsigned int ffctrl;
    unsigned int fflags;

    /* Excerpted from sys/kern/kern_event.c in FreeBSD HEAD */
    ffctrl = kev->fflags & NOTE_FFCTRLMASK;
    fflags = kev->fflags & NOTE_FFLAGSMASK;
    switch (ffctrl) {
        case NOTE_FFNOP:
            break;

        case NOTE_FFAND:
            kn->kev.fflags &= fflags;
            break;

        case NOTE_FFOR:
            kn->kev.fflags |= fflags;
            break;

        case NOTE_FFCOPY:
            kn->kev.fflags = fflags;
            break;

        default:
            /* XXX Return error? */
            break;
    }

    if ((!(kn->kev.flags & EV_DISABLE)) && kev->fflags & NOTE_TRIGGER) {
        kn->kev.fflags |= NOTE_TRIGGER;
		if (!PostQueuedCompletionStatus(kn->kn_kq->kq_iocp, 1, (ULONG_PTR) 0, (LPOVERLAPPED) kn)) {
			dbg_lasterror("PostQueuedCompletionStatus()");
			return (-1);
		}
    }

    return (0);
}

int
evfilt_user_knote_delete(struct filter *filt, struct knote *kn)
{
    return (0);
}

int
evfilt_user_knote_enable(struct filter *filt, struct knote *kn)
{
    return evfilt_user_knote_create(filt, kn);
}

int
evfilt_user_knote_disable(struct filter *filt, struct knote *kn)
{
    return evfilt_user_knote_delete(filt, kn);
}

const struct filter evfilt_user = {
    EVFILT_USER,
    evfilt_user_init,
    evfilt_user_destroy,
    evfilt_user_copyout,
    evfilt_user_knote_create,
    evfilt_user_knote_modify,
    evfilt_user_knote_delete,
    evfilt_user_knote_enable,
    evfilt_user_knote_disable,     
};