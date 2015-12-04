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

#include "./lite.h"

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

void test_evfilt_write(kqueue_t kq) {
    struct kevent kev;
    int sockfd[2];

    puts("testing EVFILT_WRITE.. ");

    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sockfd) < 0)
      abort();

    EV_SET(&kev, sockfd[1], EVFILT_WRITE, EV_ADD | EV_ENABLE, 0, 0, NULL);
    kq_event(kq, &kev, 1, 0, 0, NULL);
    puts("installed EVFILT_WRITE handler");

    if (write(sockfd[0], "hi", 2) < 2)
        abort();

    /* wait for the event */
    puts("waiting for event");
    kq_event(kq, NULL, 0, &kev, 1, NULL);
    puts ("got it");

    close(sockfd[0]);
    close(sockfd[1]);
}

void test_evfilt_signal(kqueue_t kq) {
    struct kevent kev;
    sigset_t mask;

    /* Block the normal signal handler mechanism */
    sigemptyset(&mask);
    sigaddset(&mask, SIGUSR1);
    if (sigprocmask(SIG_BLOCK, &mask, NULL) == -1)
        abort();

    EV_SET(&kev, SIGUSR1, EVFILT_SIGNAL, EV_ADD | EV_ENABLE, 0, 0, NULL);
    kq_event(kq, &kev, 1, 0, 0, NULL);
    puts("installed SIGUSR1 handler");

    if (kill(getpid(), SIGUSR1) < 0)
        abort();

    /* wait for the event */
    puts("waiting for SIGUSR1");
    kq_event(kq, NULL, 0, &kev, 1, NULL);
    puts ("got it");
}

int main() {
    kqueue_t kq;

    kq = kq_init();
    test_evfilt_signal(kq);
    test_evfilt_write(kq);
    kq_free(kq);

    puts("ok");
    exit(0);
}
