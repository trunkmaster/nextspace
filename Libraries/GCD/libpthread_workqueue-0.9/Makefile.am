# FIXME: only supports Linux for now

lib_LTLIBRARIES = libpthread_workqueue.la
include_HEADERS = include/pthread_workqueue.h
dist_man_MANS = pthread_workqueue.3

libpthread_workqueue_la_SOURCES = src/api.c src/witem_cache.c src/posix/manager.c  src/posix/thread_info.c src/posix/thread_rt.c src/linux/load.c  src/linux/thread_info.c src/linux/thread_rt.c \
  ./include/pthread_workqueue.h \
  ./src/linux/platform.h \
  ./src/posix/platform.h \
  ./src/thread_info.h \
  ./src/private.h \
  ./src/thread_rt.h \
  ./src/debug.h

libpthread_workqueue_la_CFLAGS = -I./include -I./src -Wall -Wextra -Werror -D_XOPEN_SOURCE=600 -D__EXTENSIONS__ -D_GNU_SOURCE -std=c99

check_PROGRAMS = test_api test_latency test_witem_cache
TESTS = test_api test_latency test_witem_cache

test_api_SOURCES = testing/api/test.c ./testing/api/posix_semaphore.h
test_api_CFLAGS = -I./include
test_api_LDADD = libpthread_workqueue.la -lpthread -lrt

test_latency_SOURCES = testing/latency/latency.c ./testing/latency/latency.h
test_latency_CFLAGS = -I./include
test_latency_LDADD = libpthread_workqueue.la -lpthread -lrt

test_witem_cache_SOURCES = testing/witem_cache/test.c
test_witem_cache_CFLAGS = -I./include
test_witem_cache_LDADD = libpthread_workqueue.la -lpthread -lrt
