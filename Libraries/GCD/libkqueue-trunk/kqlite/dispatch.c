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

#include <pthread.h>

#ifdef _OPENMP
#include <omp.h>
#endif /* _OPENMP */

/*
 * EXPERIMENTAL dispatching API
 */
void
kq_dispatch(kqueue_t kq, void (*cb)(kqueue_t, struct kevent)) 
{
    const int maxevents = 64; /* Should be more like 2xNCPU */
    struct kevent events[maxevents];
    ssize_t nevents;
    int i;

    for (;;) {
        nevents = kq_event(kq, NULL, 0, (struct kevent *) &events, maxevents, NULL);
        if (nevents < 0)
            abort();
        #pragma omp parallel
        {
          for (i = 0; i < nevents; i++) {
              #pragma omp single nowait
              (*cb)(kq, events[i]);
          }
        }
    }
}

