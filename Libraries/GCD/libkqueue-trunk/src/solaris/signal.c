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

#include "private.h"

/* Highest signal number supported. POSIX standard signals are < 32 */
#define SIGNAL_MAX      32

static struct sentry {
    int             st_signum;
    int             st_port;
    volatile sig_atomic_t st_count;
    struct kevent st_kev;
} sigtbl[SIGNAL_MAX];

static pthread_mutex_t sigtbl_mtx = PTHREAD_MUTEX_INITIALIZER;

static void
signal_handler(int sig)
{
    struct sentry *s;
   
    if (sig < 0 || sig >= SIGNAL_MAX) // 0..31 are valid
    {    
        dbg_printf("Received unexpected signal %d", sig);
        return;
    }
    
    s = &sigtbl[sig];
    dbg_printf("sig=%d %d", sig, s->st_signum);
    atomic_inc((volatile uint32_t *) &s->st_count);
    port_send(s->st_port, X_PORT_SOURCE_SIGNAL, &sigtbl[sig]);
    /* TODO: crash if port_send() fails? */
}

static int
catch_signal(struct filter *filt, struct knote *kn)
{
	int sig;
	struct sigaction sa;
    
    sig = kn->kev.ident;
	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = signal_handler;
	sa.sa_flags |= SA_RESTART;
	sigfillset(&sa.sa_mask);

	if (sigaction(kn->kev.ident, &sa, NULL) == -1) {
		dbg_perror("sigaction");
		return (-1);
	}

    pthread_mutex_lock(&sigtbl_mtx);
    sigtbl[sig].st_signum = sig;
    sigtbl[sig].st_port = filter_epfd(filt);
    sigtbl[sig].st_count = 0;
    memcpy(&sigtbl[sig].st_kev, &kn->kev, sizeof(struct kevent));
    pthread_mutex_unlock(&sigtbl_mtx);

    dbg_printf("installed handler for signal %d", sig);
    dbg_printf("sigtbl ptr = %p", &sigtbl[sig]);
    return (0);
}

static int
ignore_signal(int sig)
{
	struct sigaction sa;
    
	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = SIG_IGN;
	sigemptyset(&sa.sa_mask);

	if (sigaction(sig, &sa, NULL) == -1) {
		dbg_perror("sigaction");
		return (-1);
	}

    dbg_printf("removed handler for signal %d", sig);
    return (0);
}

int
evfilt_signal_knote_create(struct filter *filt, struct knote *kn)
{
    if (kn->kev.ident >= SIGNAL_MAX) {
        dbg_printf("unsupported signal number %u", 
                    (unsigned int) kn->kev.ident);
        return (-1);
    }

    kn->kev.flags |= EV_CLEAR;

    return catch_signal(filt, kn);
}

int
evfilt_signal_knote_modify(struct filter *filt UNUSED, struct knote *kn, 
                const struct kevent *kev)
{
    kn->kev.flags = kev->flags | EV_CLEAR;
    return (0);
}

int
evfilt_signal_knote_delete(struct filter *filt UNUSED, struct knote *kn)
{   
    return ignore_signal(kn->kev.ident);
}

int
evfilt_signal_knote_enable(struct filter *filt, struct knote *kn)
{
    return catch_signal(filt, kn);
}

int
evfilt_signal_knote_disable(struct filter *filt UNUSED, struct knote *kn)
{
    return ignore_signal(kn->kev.ident);
}

int
evfilt_signal_copyout(struct kevent *dst, struct knote *src, void *ptr)
{
    port_event_t *pe = (port_event_t *) ptr;
    struct sentry *ent = (struct sentry *) pe->portev_user;

    pthread_mutex_lock(&sigtbl_mtx);
    dbg_printf("sigtbl ptr = %p sig=%d", ptr, ent->st_signum);
    dst->ident = ent->st_kev.ident;
    dst->filter = EVFILT_SIGNAL;
    dst->udata = ent->st_kev.udata;
    dst->flags = ent->st_kev.flags; 
    dst->fflags = 0;
    dst->data = 1;
    pthread_mutex_unlock(&sigtbl_mtx);

    if (src->kev.flags & EV_DISPATCH || src->kev.flags & EV_ONESHOT) 
        ignore_signal(src->kev.ident);

    return (1);
}

const struct filter evfilt_signal = {
    EVFILT_SIGNAL,
    NULL,
    NULL,
    evfilt_signal_copyout,
    evfilt_signal_knote_create,
    evfilt_signal_knote_modify,
    evfilt_signal_knote_delete,
    evfilt_signal_knote_enable,
    evfilt_signal_knote_disable,     
};
