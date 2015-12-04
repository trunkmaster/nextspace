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

#include "sys/event.h"
#include "private.h"

pthread_cond_t   wait_cond = PTHREAD_COND_INITIALIZER;
pthread_mutex_t  wait_mtx = PTHREAD_MUTEX_INITIALIZER;

struct evfilt_data {
    pthread_t       wthr_id;
};

static void *
wait_thread(void *arg)
{
    struct filter *filt = (struct filter *) arg;
    struct knote *kn;
    int status, result;
    pid_t pid;
    sigset_t sigmask;

    /* Block all signals */
    sigfillset (&sigmask);
    sigdelset(&sigmask, SIGCHLD);
    pthread_sigmask(SIG_BLOCK, &sigmask, NULL);

    for (;;) {

        /* Wait for a child process to exit(2) */
        if ((pid = waitpid(-1, &status, 0)) < 0) {
            if (errno == ECHILD) {
                dbg_puts("got ECHILD, waiting for wakeup condition");
                pthread_mutex_lock(&wait_mtx);
                pthread_cond_wait(&wait_cond, &wait_mtx);
                pthread_mutex_unlock(&wait_mtx);
                dbg_puts("awoken from ECHILD-induced sleep");
                continue;
            }
            if (errno == EINTR)
                continue;
            dbg_printf("wait(2): %s", strerror(errno));
            break;
        } 

        /* Create a proc_event */
        if (WIFEXITED(status)) {
            result = WEXITSTATUS(status);
        } else if (WIFSIGNALED(status)) {
            /* FIXME: probably not true on BSD */
            result = WTERMSIG(status);
        } else {
            dbg_puts("unexpected code path");
            result = 234;           /* arbitrary error value */
        }

        /* Scan the wait queue to see if anyone is interested */
        pthread_mutex_lock(&filt->kf_mtx);
        kn = knote_lookup(filt, pid);
        if (kn != NULL) {
            kn->kev.data = result;
            kn->kev.fflags = NOTE_EXIT; 
            LIST_REMOVE(kn, entries);
            LIST_INSERT_HEAD(&filt->kf_eventlist, kn, entries);
            /* Indicate read(2) readiness */
            /* TODO: error handling */
            filter_raise(filt);
        }
        pthread_mutex_unlock(&filt->kf_mtx);
    }

    /* TODO: error handling */

    return (NULL);
}

int
evfilt_proc_init(struct filter *filt)
{
    struct evfilt_data *ed;

    if ((ed = calloc(1, sizeof(*ed))) == NULL)
        return (-1);

    if (filter_socketpair(filt) < 0) 
        goto errout;
    if (pthread_create(&ed->wthr_id, NULL, wait_thread, filt) != 0) 
        goto errout;

    return (0);

errout:
    free(ed);
    return (-1);
}

void
evfilt_proc_destroy(struct filter *filt)
{
//TODO:    pthread_cancel(filt->kf_data->wthr_id);
    close(filt->kf_pfd);
}

int
evfilt_proc_copyin(struct filter *filt, 
        struct knote *dst, const struct kevent *src)
{
    if (src->flags & EV_ADD && KNOTE_EMPTY(dst)) {
        memcpy(&dst->kev, src, sizeof(*src));
        /* TODO: think about locking the mutex first.. */
        pthread_cond_signal(&wait_cond);
    }

    if (src->flags & EV_ADD || src->flags & EV_ENABLE) {
        /* Nothing to do.. */
    }

    return (0);
}

int
evfilt_proc_copyout(struct filter *filt, 
            struct kevent *dst, 
            int maxevents)
{
    struct knote *kn;
    int nevents = 0;

    filter_lower(filt);

    LIST_FOREACH(kn, &filt->kf_eventlist, entries) {
        kevent_dump(&kn->kev);
        memcpy(dst, &kn->kev, sizeof(*dst));
        dst->fflags = NOTE_EXIT;

        if (kn->kev.flags & EV_DISPATCH) {
            KNOTE_DISABLE(kn);
        }
#if FIXME
        /* XXX - NEED TO use safe foreach instead */
        if (kn->kev.flags & EV_ONESHOT) 
            knote_free(kn);
#endif

        if (++nevents > maxevents)
            break;
        dst++;
    }

    if (!LIST_EMPTY(&filt->kf_eventlist)) 
        filter_raise(filt);

    return (nevents);
}

const struct filter evfilt_proc = {
    EVFILT_PROC,
    evfilt_proc_init,
    evfilt_proc_destroy,
    evfilt_proc_copyin,
    evfilt_proc_copyout,
};
