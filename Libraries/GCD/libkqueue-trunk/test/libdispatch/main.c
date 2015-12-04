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

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <pthread.h> 
#include <sys/event.h> 
#include <dispatch/dispatch.h> 

pthread_mutex_t mtx = PTHREAD_MUTEX_INITIALIZER;
int testnum;

void test_countdown(void);

void
say_hello(void *arg)
{
	puts("hello");
	test_countdown();
}

void
final_countdown(void *arg, size_t count)
{
	static int europe = 10;

	if (europe == 0) {
		printf("It's the final countdown..\n");
		exit(0);
	} else {
		printf("%d.. ", europe);
		fflush(stdout);
	}

	pthread_mutex_lock(&mtx);
	europe--;
	pthread_mutex_unlock(&mtx);
}

/* Adapted from:
     http://developer.apple.com/mac/articles/cocoa/introblocksgcd.html
*/
void
test_timer()
{
	dispatch_source_t timer;
	dispatch_time_t now;

    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, 
			dispatch_get_current_queue()); //NOTE: q_default doesn't work
   	now = dispatch_walltime(DISPATCH_TIME_NOW, 0);
	dispatch_source_set_timer(timer, now, 1, 1);
	dispatch_source_set_event_handler_f(timer, say_hello);
	puts("starting timer\n");
}

void
test_countdown(void)
{
	dispatch_apply_f(15,
			dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),
			NULL, final_countdown);
}


int 
main(int argc, char **argv)
{
    while (argc) {
#if TODO
        if (strcmp(argv[0], "--no-proc") == 0)
            test_proc = 0;
#endif
        argv++;
        argc--;
    }

	test_timer();

	dispatch_main();
    printf("\n---\n"
            "+OK All %d tests completed.\n", testnum - 1);
    return (0);
}
