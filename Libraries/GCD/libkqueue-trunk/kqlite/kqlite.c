/*
 * Copyright (c) 2013 Mark Heily <mark@heily.com>
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
 
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

#include "./lite.h"
#include "./utarray.h"

/* The maximum number of events that can be returned in 
   a single kq_event() call 
 */
#define EPEV_BUF_MAX 512

#include <unistd.h>

/* Debugging macros */
#define dbg_puts(s)    dbg_printf("%s", (s))
#define dbg_printf(fmt,...)  fprintf(stderr, "kq [%d]: %s(): "fmt"\n",                     \
             0 /*TODO: thread id */, __func__, __VA_ARGS__)

/* Determine what type of kernel event system to use. */
#if defined(__FreeBSD__) || defined(__APPLE__) || defined(__OpenBSD__) || defined(__NetBSD__)
#define USE_KQUEUE
#include <sys/event.h>
#elif defined(__linux__)
#define USE_EPOLL
#include <sys/epoll.h>
#include <sys/inotify.h>
#include <sys/signalfd.h>
#include <sys/timerfd.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>

//XXX - TEMPORARY DURING DEVELOPMENT
#define KQ_THREADSAFE 1

#ifdef KQ_THREADSAFE
#include <pthread.h>
#endif

static char * epoll_event_to_str(struct epoll_event *);
#else
#error Unsupported operating system type
#endif

struct kqueue {
#if defined(USE_KQUEUE)
    int kqfd;            /* kqueue(2) descriptor */
#elif defined(USE_EPOLL)
    int epfd;           /* epoll */
    int inofd;          /* inotify */
    int sigfd;          /* signalfd */
    int timefd;         /* timerfd */
    int readfd, writefd;  /* epoll descriptors for EVFILT_READ & EVFILT_WRITE */
    sigset_t sigmask;
    /* All of the active knotes for each filter. The index in the array matches
       the 'ident' parameter of the 'struct kevent' in the knote.
     */
    UT_array *knote[EVFILT_SYSCOUNT];

    /* This allows all kevents to share a single inotify descriptor.
     * Key: inotify watch descriptor returned by inotify_add_watch()
     * Value: pointer to knote 
     */
    UT_array *ino_knote;

#ifdef KQ_THREADSAFE
    pthread_mutex_t kq_mtx;
#endif

#else
#error Undefined event system
#endif
};

/* A knote is used to store information about a kevent while it is
   being monitored. Once it fires, information from the knote is returned
   to the caller.
 */
struct knote {
    struct kevent kev;
    union {
        int timerfd;        /* Each EVFILT_TIMER kevent has a timerfd */
        int ino_wd;         /* EVFILT_VNODE: index within kq->ino_knote */
    } aux;
    int deleted;            /* When EV_DELETE is used, it marks the knote deleted instead of freeing the object. This helps with threadsafety by ensuring that threads don't try to access a freed object. It doesn't help with memory usage, as the memory is never reclaimed. */
};

static inline void
kq_lock(kqueue_t kq)
{
#ifdef KQ_THREADSAFE
    if (pthread_mutex_lock(&kq->kq_mtx) != 0) 
        abort();
#endif
}

static inline void
kq_unlock(kqueue_t kq)
{
#ifdef KQ_THREADSAFE
    if (pthread_mutex_unlock(&kq->kq_mtx) != 0) 
        abort();
#endif
}

UT_icd knote_icd = { sizeof(struct knote), NULL, NULL, NULL };

/* Initialize the event descriptor */
kqueue_t
kq_init(void)
{
    struct kqueue *kq;

#if defined(USE_KQUEUE)
    if ((kq = calloc(1, sizeof(*kq))) == NULL)
        return (NULL);

    kq->kqfd = kqueue();
    if (kq->kqfd < 0) {
        free(kq);
        return (NULL);
    }
    
#elif defined(USE_EPOLL)
    struct epoll_event epev;

    if ((kq = malloc(sizeof(*kq))) == NULL)
        return (NULL);

#ifdef KQ_THREADSAFE
    if (pthread_mutex_init(&kq->kq_mtx, NULL) != 0)
        goto errout;
#endif

    /* Create an index of kevents to allow lookups from epev.data.u32 */

    for (int i = 0; i < EVFILT_SYSCOUNT; i++)
        utarray_new(kq->knote[i], &knote_icd);

    /* Initialize all the event descriptors */
    sigemptyset(&kq->sigmask);
    kq->sigfd = signalfd(-1, &kq->sigmask, 0);
    kq->inofd = inotify_init();
    kq->epfd = epoll_create(10);
    kq->readfd = epoll_create(10);
    kq->writefd = epoll_create(10);
    kq->timefd = timerfd_create(CLOCK_MONOTONIC, 0);
    if (kq->sigfd < 0 || kq->inofd < 0 || kq->epfd < 0 
            || kq->readfd < 0 || kq->writefd < 0 || kq->timefd < 0)
        goto errout;

    /* Add the signalfd descriptor to the epollset */
    epev.events = EPOLLIN;
    epev.data.u32 = EVFILT_SIGNAL;
    if (epoll_ctl(kq->epfd, EPOLL_CTL_ADD, kq->sigfd, &epev) < 0)
        goto errout;

    /* Add the readfd descriptor to the epollset */
    epev.events = EPOLLIN;
    epev.data.u32 = EVFILT_READ;
    if (epoll_ctl(kq->epfd, EPOLL_CTL_ADD, kq->readfd, &epev) < 0)
        goto errout;

    /* Add the writefd descriptor to the epollset */
    epev.events = EPOLLIN;
    epev.data.u32 = EVFILT_WRITE;
    if (epoll_ctl(kq->epfd, EPOLL_CTL_ADD, kq->writefd, &epev) < 0)
        goto errout;

    /* Add the inotify descriptor to the epollset */
    /*
    if ((kev = malloc(sizeof(*kev))) == NULL)
        goto errout;
    EV_SET(kev, EVFILT_VNODE, EVFILT_VNODE, 0, 0, 0, NULL);
    epev.events = EPOLLIN;
    epev.data.u32 = 1;
    utarray_push_back(kq->kev, kev);
    if (epoll_ctl(kq->epfd, EPOLL_CTL_ADD, kq->inofd, &epev) < 0)
        goto errout;
        */

    //TODO: consider applying FD_CLOEXEC to all descriptors

    // FIXME: check that all members of kq->wfd are valid

    return (kq);

errout:
    kq_free(kq);
    return (NULL);
#endif
}

void
kq_free(kqueue_t kq)
{
#if defined(USE_KQUEUE)
    close(kq.kqfd);
    
#elif defined(USE_EPOLL)
    close(kq->sigfd);
    close(kq->inofd);
    close(kq->epfd);
    close(kq->readfd);
    close(kq->writefd);
    close(kq->timefd);

    //FIXME: need to free each individual knote
    for (int i = 0; i < EVFILT_SYSCOUNT; i++)
        utarray_free(kq->knote[i]);

# ifdef KQ_THREADSAFE
    pthread_mutex_destroy(&kq->kq_mtx);
# endif

#endif
    free(kq);
}

#if defined(USE_EPOLL)

/* Create a knote object */
static int
knote_add(kqueue_t kq, const struct kevent *kev)
{
    struct knote *kn;

    assert(kev->filter < EVFILT_SYSCOUNT);

    kn = malloc(sizeof(*kn));
    if (kn == NULL)
        return (-1);
    memcpy (&kn->kev, kev, sizeof(kn->kev));

    kq_lock(kq);
    utarray_insert(kq->knote[kev->filter], kn, kev->ident);
    kq_unlock(kq);

    return (0);
}

/* Lookup a 'struct kevent' that was previously stored in a knote object */
static struct knote *
knote_lookup(kqueue_t kq, short filter, uint32_t ident)
{
    struct knote *p;

    kq_lock(kq);
    p = (struct knote *) utarray_eltptr(kq->knote[filter], ident);
    //TODO: refcounting
    kq_unlock(kq);

    return (p);
}

/* Add a new item to the list of events to be monitored */
static inline int
kq_add(kqueue_t kq, const struct kevent *ev)
{
    int rv = 0;
    struct epoll_event epev;
    int sigfd;

    epev.data.u32 = ev->filter;
    if (knote_add(kq, ev) < 0)
        abort(); //TODO: errorhandle

    switch (ev->filter) {
        case EVFILT_READ:
            epev.events = EPOLLIN;
            rv = epoll_ctl(kq->readfd, EPOLL_CTL_ADD, ev->ident, &epev);
            break;

        case EVFILT_WRITE:
            epev.events = EPOLLOUT;
            rv = epoll_ctl(kq->writefd, EPOLL_CTL_ADD, ev->ident, &epev);
            break;

        case EVFILT_VNODE:
            epev.events = EPOLLIN;
            rv = epoll_ctl(kq->epfd, EPOLL_CTL_ADD, ev->ident, &epev);
            rv = -1;
            break;

        case EVFILT_SIGNAL:
            kq_lock(kq);
            sigaddset(&kq->sigmask, ev->ident);
            sigfd = signalfd(kq->sigfd, &kq->sigmask, 0);
            kq_unlock(kq);
            if (sigfd < 0) {
                rv = -1;
            } else {
                rv = 0;
            }
            dbg_printf("added signal %d, rv = %d", (int)ev->ident, rv);
            break;

        case EVFILT_TIMER:
            //TODO
            rv = -1;
            break;

        default:
            rv = -1;
            return (-1);
    }

    if (rv < 0) {
        dbg_printf("failed; errno = %s", strerror(errno));
    }

    dbg_printf("done. rv = %d", rv);
//    if (rv < 0)
//        free(evcopy);
    return (rv);
}

/* Delete an item from the list of events to be monitored */
static int
kq_delete(kqueue_t kq, const struct kevent *ev)
{
    int rv = 0;
    int sigfd;
    struct epoll_event epev;

    switch (ev->ident) {
        case EVFILT_READ:
        case EVFILT_WRITE:
            rv = epoll_ctl(kq->epfd, EPOLL_CTL_DEL, ev->ident, &epev);
            break;

        case EVFILT_VNODE:
            //TODO
            break;

        case EVFILT_SIGNAL:
            kq_lock(kq);
            sigdelset(&kq->sigmask, ev->ident);
            sigfd = signalfd(kq->sigfd, &kq->sigmask, 0);
            kq_unlock(kq);
            if (sigfd < 0) {
                rv = -1;
            } else {
                rv = 0;
            }
            break;

        case EVFILT_TIMER:
            //TODO
            break;

        default:
            rv = 0;
            break;
    }
    return (rv);
}

#endif /* defined(USE_EPOLL) */

/* Read a signal from the signalfd */
static inline int
_get_signal(struct kevent *dst, kqueue_t kq)
{
    struct knote *kn;
    struct signalfd_siginfo sig;
    ssize_t n;

    n = read(kq->sigfd, &sig, sizeof(sig));
    if (n < 0 || n != sizeof(sig)) {
        abort();
    }

    kn = knote_lookup(kq, EVFILT_SIGNAL, sig.ssi_signo);
    memcpy(dst, &kn->kev, sizeof(*dst));
    
    return (0);
}

/* Equivalent to kevent() */
int kq_event(kqueue_t kq, const struct kevent *changelist, int nchanges,
	    struct kevent *eventlist, int nevents,
	    const struct timespec *timeout)
{
    int rv = 0;
    struct kevent *dst;
    //struct knote *kn;

#if defined(USE_KQUEUE)
    return kevent(kq->kqfd, changelist, nchanges, eventlist, nevents, timeout);

#elif defined(USE_EPOLL)
    struct epoll_event epev_buf[EPEV_BUF_MAX];
    struct epoll_event *epev;
    size_t epev_wait_max;
    int i, epev_cnt, eptimeout;

    /* Process each item on the changelist */
    for (i = 0; i < nchanges; i++) {
        if (changelist[i].flags & EV_ADD) {
            rv = kq_add(kq, &changelist[i]);
        } else if (changelist[i].flags & EV_DELETE) {
            rv = kq_delete(kq, &changelist[i]);
        } else {
            rv = -1;
        }
        if (rv < 0)
            return (-1);
    }

    /* Convert timeout to the format used by epoll_wait() */
    if (timeout == NULL) 
        eptimeout = -1;
    else
        eptimeout = (1000 * timeout->tv_sec) + (timeout->tv_nsec / 1000000);

    /* Wait for events and put them into a buffer */
    if (nevents > EPEV_BUF_MAX) {
        epev_wait_max = EPEV_BUF_MAX;
    } else {
        epev_wait_max = nevents;
    }
    epev_cnt = epoll_wait(kq->epfd, &epev_buf[0], epev_wait_max, eptimeout);
    if (epev_cnt < 0) {
        return (-1);        //FIXME: handle timeout
    }
    else if (epev_cnt == 0) {
        dbg_puts("timed out");
    }

    dbg_printf("whee -- got %d event(s)", epev_cnt);

    /* Determine what events have occurred and copy the result to the caller */
    for (i = 0; i < epev_cnt; i++) {
        dst = &eventlist[i];
        epev = &epev_buf[i];

        dbg_printf("got event: %s", epoll_event_to_str(epev));

        switch (epev->data.u32) {
            case EVFILT_SIGNAL:
                (void)_get_signal(dst, kq);//FIXME: errorhandle
                break;

            case EVFILT_VNODE:
                //TODO
                break;

            case EVFILT_TIMER:
                //TODO
                break;

            case EVFILT_READ:
            case EVFILT_WRITE:
                //memcpy(dst, kevp, sizeof(*dst));
                break;

            default:
                abort();
        }
    }

    return (rv == 1 ? 0 : -1);
#endif
}

#if defined(USE_EPOLL)
static char *
epoll_event_to_str(struct epoll_event *evt)
{
    static __thread char buf[128];

    if (evt == NULL)
        return "(null)";

#define EPEVT_DUMP(attrib) \
    if (evt->events & attrib) \
       strcat(&buf[0], #attrib" ");

    snprintf(&buf[0], 128, " { data = %p, events = ", evt->data.ptr);
    EPEVT_DUMP(EPOLLIN);
    EPEVT_DUMP(EPOLLOUT);
#if defined(HAVE_EPOLLRDHUP)
    EPEVT_DUMP(EPOLLRDHUP);
#endif
    EPEVT_DUMP(EPOLLONESHOT);
    EPEVT_DUMP(EPOLLET);
    strcat(&buf[0], "}\n");

    return (&buf[0]);
#undef EPEVT_DUMP
}
#endif
