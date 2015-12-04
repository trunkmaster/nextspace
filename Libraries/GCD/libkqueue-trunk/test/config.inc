#!/bin/sh

program=libkqueue-test
version=0.1
cflags="-g -O0 -Wall -Werror -Wl,-rpath,.."
sources="main.c kevent.c test.c proc.c read.c signal.c timer.c vnode.c"

pre_configure_hook() {
 
  check_header "err.h"
  check_header "sys/event.h" \
      && sys_event_h="sys/event.h" \
      || {
            sys_event_h="../include/sys/event.h"
            cflags="$cflags -I../include -L.."
            if [ "$target" = "windows" ] 
            then
              ldadd="$ldadd ../libkqueue.so"
            else
              ldadd="$ldadd ../libkqueue_debug.a -lpthread -lrt"
            fi
         }

  check_symbol $sys_event_h EV_DISPATCH
  check_symbol $sys_event_h EV_RECEIPT
  check_symbol $sys_event_h NOTE_TRUNCATE 
  check_symbol $sys_event_h EVFILT_TIMER
  check_symbol $sys_event_h EVFILT_USER && \
     sources="$sources user.c"

  if [ "$target" = "solaris" ] 
  then
      ldadd="$ldadd -lsocket -lnsl -m64"

      check_symbol port.h PORT_SOURCE_FILE
  fi

  if [ "$target" = "linux" ] 
  then
      cflags="$cflags -rdynamic"
  fi

  if [ "$target" = "windows" ] 
  then
      cflags="$cflags -march=i686"
      ldflags="$ldflags -march=i686"
      ldadd="$ldadd -lws2_32"
      # KLUDGE: to remove signal.c, proc.c
      sources="main.c kevent.c test.c read.c timer.c user.c vnode.c"
  fi

}
