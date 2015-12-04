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

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <err.h>

#include <pthread.h> 
#include <sys/event.h> 

/* Number of threads to create */
static const int nthreads = 64;

/* Number of iterations performed by each thread */
static const int nrounds = 1000000;

//pthread_mutex_t mtx = PTHREAD_MUTEX_INITIALIZER;

void
test_kqueue_conc(void)
{
    int i, fd;

    for (i = 0; i < 256; i++) {
        fd = kqueue();
        if (i < 0)
            err(1, "kqueue");
        close(fd);
    }
}

void *
test_harness(void *arg)
{
    int id = (long) arg;
    int i;
    int kqfd;

    kqfd = kqueue();
    if (kqfd < 0)
        err(1, "kqueue");

    printf("thread %d runs %d\n", id, id % 4);

    //test_kqueue_conc();
    for (i = 0; i < nrounds; i++) {
        switch (id % 4) {
            case 0: test_evfilt_user(kqfd);
                    break;
            case 1: test_evfilt_read(kqfd);
                    break;
            case 2: test_evfilt_timer(kqfd);
                    break;
            case 3: test_evfilt_vnode(kqfd);
                    break;
        }
        printf("thread %d round %d / %d\n", id, i, nrounds);
    }
    printf("thread %d done\n", id);
}

int 
main(int argc, char **argv)
{
    pthread_t tid[nthreads];
    long i;

    for (i=0; i<nthreads; i++) {
        if (pthread_create(&tid[i], NULL, test_harness, (void *)i) != 0)
            err(1, "pthread_create");
    }
    for (i=0; i<nthreads; i++) {
        if (pthread_join(tid[i], NULL) != 0)
            err(1, "pthread_join");
    }
    printf("\n---\n+OK All tests completed.\n");
    exit (0);
}
