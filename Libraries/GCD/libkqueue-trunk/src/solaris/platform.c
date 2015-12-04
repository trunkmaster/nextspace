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

const struct filter evfilt_vnode = EVFILT_NOTIMPL;
const struct filter evfilt_proc  = EVFILT_NOTIMPL;

/*
 * Per-thread port event buffer used to ferry data between
 * kevent_wait() and kevent_copyout().
 */
static __thread port_event_t evbuf[MAX_KEVENT];

#ifndef NDEBUG

/* Dump a poll(2) events bitmask */
static char *
poll_events_dump(short events)
{
    static __thread char buf[512];

#define _PL_DUMP(attrib) \
    if (events == attrib) \
       strcat(&buf[0], " "#attrib);

    snprintf(&buf[0], 512, "events = %hd 0x%o (", events, events);
    _PL_DUMP(POLLIN);
    _PL_DUMP(POLLPRI);
    _PL_DUMP(POLLOUT);
    _PL_DUMP(POLLRDNORM);
    _PL_DUMP(POLLRDBAND);
    _PL_DUMP(POLLWRBAND);
    _PL_DUMP(POLLERR);
    _PL_DUMP(POLLHUP);
    _PL_DUMP(POLLNVAL);
    strcat(&buf[0], ")");

    return (&buf[0]);

#undef _PL_DUMP
}

static char *
port_event_dump(port_event_t *evt)
{
    static __thread char buf[512];

    if (evt == NULL) {
        snprintf(&buf[0], sizeof(buf), "NULL ?!?!\n");
        goto out;
    }

#define PE_DUMP(attrib) \
    if (evt->portev_source == attrib) \
       strcat(&buf[0], #attrib);

    snprintf(&buf[0], 512,
                " { object = %u, user = %p, %s, source = %d (",
                (unsigned int) evt->portev_object,
                evt->portev_user,
                poll_events_dump(evt->portev_events),
                evt->portev_source);
    PE_DUMP(PORT_SOURCE_AIO);
    PE_DUMP(PORT_SOURCE_FD);
    PE_DUMP(PORT_SOURCE_TIMER);
    PE_DUMP(PORT_SOURCE_USER);
    PE_DUMP(PORT_SOURCE_ALERT);
    strcat(&buf[0], ") }");
#undef PE_DUMP

out:
    return (&buf[0]);
}

#endif /* !NDEBUG */

int
solaris_kqueue_init(struct kqueue *kq)
{
    if ((kq->kq_id = port_create()) < 0) {
        dbg_perror("port_create(2)");
        return (-1);
    }
    dbg_printf("created event port; fd=%d", kq->kq_id);

    if (filter_register_all(kq) < 0) {
        close(kq->kq_id);
        return (-1);
    }

    return (0);
}

void
solaris_kqueue_free(struct kqueue *kq)
{
    (void) close(kq->kq_id);
    dbg_printf("closed event port; fd=%d", kq->kq_id);
}

int
solaris_kevent_wait(
        struct kqueue *kq, 
        int nevents UNUSED,
        const struct timespec *ts)

{
    int rv;
    uint_t nget = 1;

    reset_errno();
    dbg_puts("waiting for events");
    rv = port_getn(kq->kq_id, &evbuf[0], 1, &nget, (struct timespec *) ts);

    dbg_printf("rv=%d errno=%d (%s) nget=%d", rv, errno, strerror(errno), nget);
    if ((rv < 0) && (nget < 1)) {
        if (errno == ETIME) {
            dbg_puts("no events within the given timeout");
            return (0);
        }
        if (errno == EINTR) {
            dbg_puts("signal caught");
            return (-1);
        }
        dbg_perror("port_getn(2)");
        return (-1);
    }

    return (nget);
}

int
solaris_kevent_copyout(struct kqueue *kq, int nready,
        struct kevent *eventlist, int nevents UNUSED)
{
    port_event_t  *evt;
    struct knote  *kn;
    struct filter *filt;
    int i, rv, skip_event, skipped_events = 0;

    for (i = 0; i < nready; i++) {
        evt = &evbuf[i];
        kn = evt->portev_user;
        skip_event = 0;
        dbg_printf("event=%s", port_event_dump(evt));

        switch (evt->portev_source) {
            case PORT_SOURCE_FD:
//XXX-FIXME WHAT ABOUT WRITE???
                filter_lookup(&filt, kq, EVFILT_READ);
                rv = filt->kf_copyout(eventlist, kn, evt);

                /* For sockets, the event port object must be reassociated
                   after each event is retrieved. */
                if (rv == 0 && !(kn->kev.flags & EV_DISPATCH 
                            || kn->kev.flags & EV_ONESHOT)) {
                    rv = filt->kn_create(filt, kn);
                }
                
                if (eventlist->data == 0) // if zero data is returned, we raced with a read of data from the socket, skip event to have proper semantics
                    skip_event = 1;
                
                break;

            case PORT_SOURCE_TIMER:
                filter_lookup(&filt, kq, EVFILT_TIMER);
                rv = filt->kf_copyout(eventlist, kn, evt);
                break;

            case PORT_SOURCE_USER:
                switch (evt->portev_events) {
                    case X_PORT_SOURCE_SIGNAL:
                        filter_lookup(&filt, kq, EVFILT_SIGNAL);
                        rv = filt->kf_copyout(eventlist, kn, evt);
                        break;
                    case X_PORT_SOURCE_USER:
                        filter_lookup(&filt, kq, EVFILT_USER);
                        rv = filt->kf_copyout(eventlist, kn, evt);
                        break;
                    default:
                dbg_puts("unsupported portev_events");
                abort();
                }
                break;

            default:
                dbg_puts("unsupported source");
                abort();
        }

        if (rv < 0) {
            dbg_puts("kevent_copyout failed");
            return (-1);
        }

        /*
         * Certain flags cause the associated knote to be deleted
         * or disabled.
         */
        if (eventlist->flags & EV_DISPATCH) 
            knote_disable(filt, kn); //TODO: Error checking
        if (eventlist->flags & EV_ONESHOT) 
        {
            knote_delete(filt, kn); //TODO: Error checking
        }

        if (skip_event)
            skipped_events++;
        else
            eventlist++;
    }

    return (nready - skipped_events);
}

const struct kqueue_vtable kqops =
{
    solaris_kqueue_init,
    solaris_kqueue_free,
    solaris_kevent_wait,
    solaris_kevent_copyout,
    NULL,
    NULL,
    posix_eventfd_init,
    posix_eventfd_close,
    posix_eventfd_raise,
    posix_eventfd_lower,
    posix_eventfd_descriptor
};
