libkqueue
=========

A user space implementation of the kqueue(2) kernel event notification mechanism
libkqueue acts as a translator between the kevent structure and the native
kernel facilities on Linux, Android, Solaris, and Windows.

Supported Event Types
---------------------

* vnode
* socket
* proc
* user
* timer

Installation - Linux, Solaris
-----------------------------

    ./configure
    make
    make install

Installation - Red Hat
----------------------

    ./configure
    make package
    rpm -i *.rpm

Installation - Android
----------------------

    ruby ./configure.rb --host=arm-linux-androideabi \
                        --with-ndk=/opt/android-ndk-r8c \
                        --with-sdk=/opt/android-sdks
    make

Running Unit Tests
------------------

    ./configure
    make
    make check

Building Applications
---------------------

    CFLAGS += -I/usr/include/kqueue
    LDFLAGS += -lkqueue

Tutorials & Examples
--------------------

[Kqueues for Fun and Profit](http://doc.geoffgarside.co.uk/kqueue)

[Handling TCP Connections with Kqueue Event Notification](http://eradman.com/posts//kqueue-tcp.html)

Releases History
----------------

2.0 add support for Android _2013-04-29_

1.0 stable relesae for Linux, Solaris, and Windows _2010-09-18_
