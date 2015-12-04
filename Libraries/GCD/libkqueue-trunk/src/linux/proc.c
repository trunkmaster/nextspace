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

#include <errno.h>
#include <err.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/queue.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <unistd.h>

#include <limits.h>
#include <sys/inotify.h>
#include <sys/epoll.h>

#include "sys/event.h"
#include "private.h"


/* XXX-FIXME Should only have one wait_thread per process.
   Now, there is one thread per kqueue
 */
struct evfilt_data {
    pthread_t       wthr_id;
    pthread_cond_t   wait_cond;
    pthread_mutex_t  wait_mtx;
};

//FIXME: WANT: static void *
void *
wait_thread(void *arg)
{
    struct filter *filt = (struct filter *) arg;
    uint64_t counter = 1;
    const int options = WEXITED | WNOWAIT; 
    struct knote *kn;
    siginfo_t si;
    sigset_t sigmask;

    /* Block all signals */
    sigfillset (&sigmask);
    pthread_sigmask(SIG_BLOCK, &sigmask, NULL);

    for (;;) {

        /* Wait for a child process to exit(2) */
        if (waitid(P_ALL, 0, &si, options) != 0) {
            if (errno == ECHILD) {
                dbg_puts("got ECHILD, waiting for wakeup condition");
                pthread_mutex_lock(&filt->kf_data->wait_mtx);
                pthread_cond_wait(&filt->kf_data->wait_cond, &filt->kf_data->wait_mtx);
                pthread_mutex_unlock(&filt->kf_data->wait_mtx);
                dbg_puts("awoken from ECHILD-induced sleep");
                continue;
            }

            dbg_puts("  waitid(2) returned");
            if (errno == EINTR)
                continue;
            dbg_perror("waitid(2)");
            break; 
        }

        /* Scan the wait queue to see if anyone is interested */
        kn = knote_lookup(filt, si.si_pid);
        if (kn == NULL) 
            continue;

        /* Create a proc_event */
        if (si.si_code == CLD_EXITED) {
            kn->kev.data = si.si_status;
        } else if (si.si_code == CLD_KILLED) {
            /* FIXME: probably not true on BSD */
            /* FIXME: arbitrary non-zero number */
            kn->kev.data = 254; 
        } else {
            /* Should never happen. */
            /* FIXME: arbitrary non-zero number */
            kn->kev.data = 1; 
        }

        knote_enqueue(filt, kn);

        /* Indicate read(2) readiness */
        if (write(filt->kf_pfd, &counter, sizeof(counter)) < 0) {
            if (errno != EAGAIN) {
                dbg_printf("write(2): %s", strerror(errno));
                /* TODO: set filter error flag */
                break;
                }
        }
    }

    /* TODO: error handling */

    return (NULL);
}

int
evfilt_proc_init(struct filter *filt)
{
#if FIXME
    struct evfilt_data *ed;
    int efd = -1;

    if ((ed = calloc(1, sizeof(*ed))) == NULL)
        return (-1);
    filt->kf_data = ed;

    pthread_mutex_init(&ed->wait_mtx, NULL);
    pthread_cond_init(&ed->wait_cond, NULL);
    if ((efd = eventfd(0, 0)) < 0) 
        goto errout;
    if (fcntl(filt->kf_pfd, F_SETFL, O_NONBLOCK) < 0) 
        goto errout;
    filt->kf_pfd = efd;
    if (pthread_create(&ed->wthr_id, NULL, wait_thread, filt) != 0) 
        goto errout;


    return (0);

errout:
    if (efd >= 0)
        close(efd);
    free(ed);
    close(filt->kf_pfd);
    return (-1);
#endif
    return (-1); /*STUB*/
}

void
evfilt_proc_destroy(struct filter *filt)
{
//TODO:    pthread_cancel(filt->kf_data->wthr_id);
    close(filt->kf_pfd);
}

int
evfilt_proc_copyout(struct filter *filt, 
            struct kevent *dst, 
            int maxevents)
{
    struct knote *kn;
    int nevents = 0;
    uint64_t cur;

    /* Reset the counter */
    if (read(filt->kf_pfd, &cur, sizeof(cur)) < sizeof(cur)) {
        dbg_printf("read(2): %s", strerror(errno));
        return (-1);
    }
    dbg_printf("  counter=%llu", (unsigned long long) cur);

    for (kn = knote_dequeue(filt); kn != NULL; kn = knote_dequeue(filt)) {
        kevent_dump(&kn->kev);
        memcpy(dst, &kn->kev, sizeof(*dst));

        if (kn->kev.flags & EV_DISPATCH) {
            KNOTE_DISABLE(kn);
        }
        if (kn->kev.flags & EV_ONESHOT) {
            knote_free(filt, kn);
        } else {
            kn->kev.data = 0; //why??
        }


        if (++nevents > maxevents)
            break;
        dst++;
    }

    if (knote_events_pending(filt)) {
    /* XXX-FIXME: If there are leftover events on the waitq, 
       re-arm the eventfd. list */
        abort();
    }

    return (nevents);
}
 
int
evfilt_proc_knote_create(struct filter *filt, struct knote *kn)
{
    return (0); /* STUB */
}

int
evfilt_proc_knote_modify(struct filter *filt, struct knote *kn, 
        const struct kevent *kev)
{
    return (0); /* STUB */
}

int
evfilt_proc_knote_delete(struct filter *filt, struct knote *kn)
{
    return (0); /* STUB */
}

int
evfilt_proc_knote_enable(struct filter *filt, struct knote *kn)
{
    return (0); /* STUB */
}

int
evfilt_proc_knote_disable(struct filter *filt, struct knote *kn)
{
    return (0); /* STUB */
}

const struct filter evfilt_proc_DEADWOOD = {
    0, //XXX-FIXME broken: EVFILT_PROC,
    evfilt_proc_init,
    evfilt_proc_destroy,
    evfilt_proc_copyout,
    evfilt_proc_knote_create,
    evfilt_proc_knote_modify,
    evfilt_proc_knote_delete,
    evfilt_proc_knote_enable,
    evfilt_proc_knote_disable,
};
