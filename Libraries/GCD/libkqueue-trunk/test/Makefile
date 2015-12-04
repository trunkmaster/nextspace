#
# Copyright (c) 2009 Mark Heily <mark@heily.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

tests=kqtest kqtest_debug lockstat static-lib-test

include config.mk

all: $(tests)

lockstat: lockstat.c
	$(CC) -o lockstat $(CFLAGS) lockstat.c $(LDADD)

kqtest: $(SOURCES)
	$(CC) -pg -o kqtest -DMAKE_STATIC=1 $(CFLAGS) $(SOURCES) ../libkqueue.a -lpthread

kqtest_debug: $(SOURCES)
	$(CC) -pg -o kqtest_debug -DMAKE_STATIC=1 $(CFLAGS) $(SOURCES) ../libkqueue_debug.a -lpthread

static-lib-test: $(SOURCES)
	$(CC) -o static-lib-test -DMAKE_STATIC=1 $(CFLAGS) $(SOURCES) ../libkqueue.a -lpthread

check: kqtest
	./kqtest $(KQTEST_OPTS)

debug: kqtest
	gdb ./kqtest $(KQTEST_OPTS)

valgrind: kqtest
	valgrind --tool=memcheck --leak-check=full --show-reachable=yes --num-callers=20 --track-fds=yes ./kqtest

helgrind: kqtest
	valgrind --tool=helgrind ./kqtest -c 25 -n 1

callgrind: kqtest
	rm -f callgrind.*
	valgrind --tool=callgrind --branch-sim=yes ./kqtest || true
	kcachegrind callgrind.*

cachegrind: kqtest
	rm -f cachegrind.*
	valgrind --tool=cachegrind --branch-sim=yes ./kqtest || true
	#CLI:
	#cg_annotate cachegrind.*
	#GUI:
	kcachegrind

check-installed:
	$(CC) -o kqtest $(CFLAGS) $(SOURCES) $(LDADD) -lkqueue
	./kqtest

check-libtool:
	gcc $(CFLAGS) -c *.c
	libtool --mode=link gcc -g -O0 -o kqtest *.o $(LIBDIR)/libkqueue.la
	./kqtest

distclean: clean 
	rm -f config.mk config.h
	for x in libdispatch stress; do cd $$x && make distclean && cd .. ; done

edit:
	$(EDITOR) *.[ch]

clean:
	rm -f *.o *.a $(tests)
	for x in libdispatch stress; do cd $$x && make clean && cd ..; done
