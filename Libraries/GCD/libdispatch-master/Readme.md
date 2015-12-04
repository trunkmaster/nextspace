libdispatch for Linux
=====================

Pthreads getting you down? [libdispatch](http://libdispatch.macosforge.org), aka Grand Central Dispatch (GCD) is Apple's high-performance event-handling library, introduced in OS X Snow Leopard. It provides asynchronous task queues, monitoring of file descriptor read and write-ability, asynchronous I/O (for sockets *and* regular files), readers-writer locks, parallel for-loops, sane signal handling, periodic timers, semaphores and more. You'll want to read over Apple's [API reference](http://developer.apple.com/library/ios/#documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html).

Currently, the trunk of the [official SVN repository](http://libdispatch.macosforge.org/trac/browser) doesn't build on Linux; the last revision that builds out-of-the-box is `r199`, but that revision doesn't contain any of the nifty APIs added in OS X Lion, e.g. asynchronous I/O. This repo applies some patches by Mark Heily, taken from [his post to the libdispatch mailing list](http://lists.macosforge.org/pipermail/libdispatch-dev/2012-August/000676.html), along with some other fixes that I've cobbled together. It has not been exhaustively tested, but it seems to work well enough.

Patches are very welcome!

### Changes from Apple's official version
I've added the ability to integrate libdispatch's main queue with third-party run-loops, e.g. GLib's `GMainLoop`. Call `dispatch_get_main_queue_eventfd_np()` to get a file descriptor your run-loop can monitor for reading; when it becomes readable, call `eventfd_read(2)` to acknowledge the wakeup, then call `dispatch_main_queue_drain_np()` to execute the pending tasks.

I've also added missing `_f` variants for several functions in `data.h` and `io.h` that took [Objective-C blocks](http://developer.apple.com/library/ios/#documentation/cocoa/Conceptual/Blocks/Articles/00_Introduction.html) only: look for the functions with `_np` appended to them. Although you can make full use of libdispatch with compilers like GCC that don't support blocks, it is not advisable to build libdispatch itself with anything other than Clang, as the dispatch i/o portion cannot be built without compiler support for blocks.

Prerequisities
--------------
- [libBlocksRuntime](https://github.com/mheily/blocks-runtime)
- [libpthread_workqueue](https://github.com/mheily/libpwq)
- [libkqueue](https://github.com/mheily/libkqueue)
- [Clang](http://llvm.org)
- [CMake](http://cmake.org)

How to build
------------
The following does the job on Ubuntu 12.10:

    sudo apt-get install libblocksruntime-dev libkqueue-dev libpthread-workqueue-dev cmake
    git clone git://github.com/nickhutchinson/libdispatch.git
    mkdir libdispatch-build && cd libdispatch-build
    cmake ../libdispatch -DCMAKE_C_COMPILER=clang -DCMAKE_BUILD_TYPE=Release
    make
    sudo make install

[![Build Status](https://travis-ci.org/nickhutchinson/libdispatch.svg?branch=master)](https://travis-ci.org/nickhutchinson/libdispatch)

Testing
-------
The included test suite builds and runs on Linux (just run `make check`). Last I checked, a few tests failed:

- dispatch_starfish
- dispatch_vnode

Test failure results are [here](https://gist.github.com/3903724). The dispatch_starfish failure can probably be ignored, but the dispatch_vnode failure seems to indicate some more serious issue, possibly a bug in libkqueue. It might be best to avoid using `dispatch_source_create()` with `DISPATCH_SOURCE_TYPE_VNODE` for now...

Demo
-------
    cat << "EOF" > dispatch_test.c
    #include <dispatch/dispatch.h>
    #include <stdio.h>

    static void timer_did_fire(void *context) { printf("Strawberry fields...\n"); }

    static void write_completion_handler(dispatch_data_t unwritten_data, int error, void *context) {
        if (!unwritten_data && error == 0)
           printf("Dispatch I/O wrote everything to stdout. Hurrah.\n");
    }

    static void read_completion_handler(dispatch_data_t data, int error, void *context) {
        int fd = (intptr_t)context;
        close(fd);
        
        dispatch_write_f_np(STDOUT_FILENO, data, dispatch_get_main_queue(),
                            NULL, write_completion_handler);
    }
     
    int main(int argc, const char *argv[]) {
        dispatch_source_t timer = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());

        dispatch_source_set_event_handler_f(timer, timer_did_fire);
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC,
                                  0.5 * NSEC_PER_SEC);
        dispatch_resume(timer);

        int fd = open("dispatch_test.c", O_RDONLY);

        dispatch_read_f_np(fd, SIZE_MAX, dispatch_get_main_queue(), (void *)(intptr_t)fd,
                        read_completion_handler);

        dispatch_main();
        return 0;
    }
    EOF

    clang dispatch_test.c -I/usr/local/include -L/usr/local/lib -ldispatch -o dispatchTest
    ./dispatchTest
