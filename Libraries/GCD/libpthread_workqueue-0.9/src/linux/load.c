/*
 * Copyright (c) 2012, Mark Heily <mark@heily.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

#include "../private.h"

/* Problem: does not include the length of the runqueue, and
     subtracting one from the # of actually running processes will
     always show free CPU even when there is none. */
#ifdef DEADWOOD 
unsigned int
linux_get_kse_count(void)
{
    int     fd, nkse;
    char    buf[100];
    char   *p;
    ssize_t len;

    fd = open("/proc/loadavg", O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        dbg_perror("open() of /proc/loadavg");
        return (-1);
    }

    len = read(fd, &buf, sizeof(buf));
    if (len < 0) {
        dbg_perror("read() of /proc/loadavg");
        return (-1);
    }

    /* See proc(5) for the format of the output of /proc/loadavg. 
     * We are only interested in the first part of the fourth field:
     *   the number of currently executing kernel scheduling entities
     */
    p = strchr((char *) &buf[0], '/');
    if (p == NULL)
        return (-1);
    *p-- = '\0';
    while (*p != ' ') {
        p--;
    }
    nkse = atoi(p + 1);

    (void) close(fd);

    return ((unsigned int) nkse);
}
#endif /*DEADWOOD*/

unsigned int
linux_get_runqueue_length(void)
{
    int fd;
    char   buf[16384];
    char   *p;
    ssize_t  len = 0;
    unsigned int     runqsz = 0;

    fd = open("/proc/stat", O_RDONLY);
    if (fd <0) {
        dbg_perror("open() of /proc/stat");
        return (1);
    }

    /* Read the entire file into memory */
    len = read(fd, &buf, sizeof(buf) - 1);
    if (len < 0) {
        dbg_perror("read failed");
        goto out;
    }
    //printf("buf=%s len=%d\n", buf, (int)len);

    /* Search for 'procs_running %d' */
    p = strstr(buf, "procs_running");
    if (p != NULL) {
        runqsz = atoi(p + 14);
    }

out:
    if (runqsz == 0) {
        /* TODO: this should be an assertion */
        runqsz = 1; //WORKAROUND
    }

    (void) close(fd);

    return (runqsz);
}
