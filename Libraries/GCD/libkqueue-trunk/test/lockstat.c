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

#include <err.h>
#include <pthread.h>
#include "../src/common/private.h"

int DEBUG_KQUEUE = 1;
char * KQUEUE_DEBUG_IDENT = "lockstat";

struct foo {
    tracing_mutex_t foo_lock;
};

void *test_assert_unlocked(void *_x)
{
    struct foo *x = (struct foo *) _x;
    tracing_mutex_assert(&x->foo_lock, MTX_UNLOCKED);
    pthread_exit(NULL);
}

void *test_assert_locked(void *_x)
{
    struct foo *x = (struct foo *) _x;
    puts("The following assertion should fail");
    tracing_mutex_assert(&x->foo_lock, MTX_LOCKED);
    pthread_exit(NULL);
}

/*
 * Test the lockstat.h API
 */
int main() {
    struct foo x;
    pthread_t tid;
    void *rv;
    
    tracing_mutex_init(&x.foo_lock, NULL);
    tracing_mutex_lock(&x.foo_lock);
    tracing_mutex_assert(&x.foo_lock, MTX_LOCKED);
    tracing_mutex_unlock(&x.foo_lock);
    tracing_mutex_assert(&x.foo_lock, MTX_UNLOCKED);

    /*
     * Ensure that the assert() function works when there
     * are multiple threads contenting for the mutex.
     */
    tracing_mutex_lock(&x.foo_lock);
    if (pthread_create(&tid, NULL, test_assert_unlocked, &x) != 0)
        err(1, "pthread_create");
    pthread_join(tid, &rv);
    tracing_mutex_unlock(&x.foo_lock);
    tracing_mutex_lock(&x.foo_lock);
    if (pthread_create(&tid, NULL, test_assert_locked, &x) != 0)
        err(1, "pthread_create");
    sleep(3); // Crude way to ensure the other thread is scheduled
    pthread_join(tid, &rv);
    tracing_mutex_unlock(&x.foo_lock);

    puts("+OK");
    return (0);
}
