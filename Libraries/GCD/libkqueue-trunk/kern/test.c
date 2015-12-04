/*
 * Copyright (c) 2010 Mark Heily <mark@heily.com>
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

#include <err.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "../include/sys/event.h"

int 
main(int argc, char **argv)
{
    struct kevent kev;
    int fd;

    fd = open("/dev/kqueue", O_RDWR);
    if (fd < 0)
        err(1, "open()");
    printf("kqfd = %d\n", fd);

    EV_SET(&kev, 1, EVFILT_READ, EV_ADD, 0, 0, NULL);
#if OLD
    int x;

    x = 1;
	if (ioctl(fd, 1234, (char *) &x) < 0)
        err(1, "ioctl");
    x = 2;
	if (ioctl(fd, 1234, (char *) &x) < 0)
        err(1, "ioctl");
#endif
	if (write(fd, &kev, sizeof(kev)) < 0)
        err(1, "write");

    close(fd);
    puts("ok");

    exit(0);
}
