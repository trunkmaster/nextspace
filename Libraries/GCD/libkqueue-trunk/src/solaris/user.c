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

#include "private.h"

int
evfilt_user_copyout(struct kevent *dst, struct knote *src, void *ptr UNUSED)
{
    //port_event_t *pe = (port_event_t *) ptr;
  
    memcpy(dst, &src->kev, sizeof(*dst));
    dst->fflags &= ~NOTE_FFCTRLMASK;     //FIXME: Not sure if needed
    dst->fflags &= ~NOTE_TRIGGER;
    if (src->kev.flags & EV_ADD) {
        /* NOTE: True on FreeBSD but not consistent behavior with
           other filters. */
        dst->flags &= ~EV_ADD;
    }
    if (src->kev.flags & EV_CLEAR)
        src->kev.fflags &= ~NOTE_TRIGGER;
    /* FIXME: This shouldn't be necessary in Solaris...
       if (src->kev.flags & (EV_DISPATCH | EV_CLEAR | EV_ONESHOT))
       eventfd_lower(filt->kf_efd);
     */
    /* FIXME: should move to kqops.copyout()
    if (src->kev.flags & EV_DISPATCH) {
            KNOTE_DISABLE(src);
            src->kev.fflags &= ~NOTE_TRIGGER;
        } else if (src->kev.flags & EV_ONESHOT) {
            knote_free(filt, src);
        }
     */

    return (1);
}


int
evfilt_user_knote_create(struct filter *filt UNUSED, struct knote *kn UNUSED)
{
#if TODO
    u_int ffctrl;

    //determine if EV_ADD + NOTE_TRIGGER in the same kevent will cause a trigger */
    if ((!(dst->kev.flags & EV_DISABLE)) && src->fflags & NOTE_TRIGGER) {
        dst->kev.fflags |= NOTE_TRIGGER;
        eventfd_raise(filt->kf_pfd);
    }

#endif
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
        return (port_send(filter_epfd(filt), X_PORT_SOURCE_USER, kn)); 
    }

    return (0);
}

int
evfilt_user_knote_delete(struct filter *filt UNUSED, struct knote *kn UNUSED)
{
    return (0);
}

int
evfilt_user_knote_enable(struct filter *filt UNUSED, struct knote *kn UNUSED)
{
    /* FIXME: what happens if NOTE_TRIGGER is in fflags?
       should the event fire? */
    return (0);
}

int
evfilt_user_knote_disable(struct filter *filt UNUSED, struct knote *kn UNUSED)
{
    return (0);
}

const struct filter evfilt_user = {
    EVFILT_USER,
    NULL,
    NULL,
    evfilt_user_copyout,
    evfilt_user_knote_create,
    evfilt_user_knote_modify,
    evfilt_user_knote_delete,
    evfilt_user_knote_enable,
    evfilt_user_knote_disable,   
};
