program="libkqueue"
version="2.0a"
abi_major="0"
abi_minor="0"
abi_version="$abi_major.$abi_minor"
cflags="-Wall -Wextra -Wno-missing-field-initializers -Werror -g -O2 -std=c99 -D_XOPEN_SOURCE=600"
ldflags=""
sources="src/common/filter.c src/common/knote.c src/common/map.c
         src/common/kevent.c src/common/kqueue.c" 
libdepends=""
deps="src/common/private.h src/common/debug.h"
mans="kqueue.2"
headers="src/common/private.h"
extra_dist="*.in"
subdirs="src include test"

# Package metadata
pkg_summary="Emulates the kqueue and kevent system calls"
pkg_description="Emulates the kqueue and kevent system calls"
license="BSD"
author="Mark Heily"

pre_configure_hook() {
  if [ "$debug" = "yes" ] ; then
      cflags="$cflags -g3 -O0 -rdynamic"
  fi

  if [ "$target" != "windows" ] ; then
      cflags="$cflags -fpic"
  fi

  optional_headers="err.h"

  libdepends=" -L$libdir"
  if [ $target = "linux" ] ; then

      check_symbol sys/epoll.h EPOLLRDHUP

      # TODO - note this as a GCC 4.X dependency
      cflags="$cflags -fvisibility=hidden"

      libdepends="$libdepends -lpthread -lrt"
      required_headers="sys/epoll.h sys/inotify.h"
      optional_headers="sys/signalfd.h sys/timerfd.h sys/eventfd.h"
  fi

  if [ $target = "solaris" ] ; then
      cflags="$cflags -m64"
      ldflags="$ldflags -m64"
      libdepends="$libdepends -lsocket -lnsl"
  fi
}

post_configure_hook() {
    finalize target "$target"

    platform="src/posix/platform.c"
    evfilt_signal="src/posix/signal.c"
    evfilt_proc="src/$target/proc.c"
    evfilt_socket="src/$target/socket.c"
    evfilt_timer="src/posix/timer.c"
    evfilt_user="src/posix/user.c"
    evfilt_vnode="src/$target/vnode.c"

    if [ $target = "linux" ] ; then
      evfilt_user="src/linux/user.c"
      evfilt_socket="src/linux/read.c src/linux/write.c"

       #XXX-FIXME disabled
       evfilt_proc=""

      if [ "$have_sys_signalfd_h" = "yes" ] ; then
          evfilt_signal="src/linux/signal.c"
      fi
      if [ "$have_sys_timerfd_h" = "yes" ] ; then
          evfilt_timer="src/linux/timer.c"
      fi
      platform="$platform src/linux/platform.c"
    fi      

    if [ $target = "solaris" ] ; then
          cflags="$cflags -D__EXTENSIONS__"
          platform="$platform src/solaris/platform.c"
          evfilt_timer="src/solaris/timer.c"
          evfilt_user="src/solaris/user.c"
          evfilt_signal="src/solaris/signal.c"
          evfilt_proc=""
          evfilt_vnode=""
    fi      

    # FIXME: This will compile but not actually work
    if [ $target = "freebsd" ] ; then
          evfilt_signal="src/posix/signal.c"
          evfilt_proc=""
          evfilt_socket=""
          evfilt_timer=""
          evfilt_vnode=""
    fi

    if [ $target = "windows" ] ; then
          platform="src/windows/platform.c"
	  cflags="$cflags -march=i686 -lws2_32"
	  ldflags="$ldflags -march=i686"
          ldadd="-lws2_32"
          evfilt_proc=""
          evfilt_signal=""
	  #evfilt_socket="src/windows/read.c src/linux/write.c"
	  evfilt_socket="src/windows/read.c"
          evfilt_timer="src/windows/timer.c"
          evfilt_user="src/windows/user.c"
          evfilt_vnode=""
    fi
    
    sources="$sources $platform  
            $evfilt_signal $evfilt_proc 
             $evfilt_socket $evfilt_timer $evfilt_user $evfilt_vnode"
}
