# FreeBSD hybrid CoreFoundation

`Packaging/Sources/1_build_libcorefoundation.sh` builds a hybrid
CoreFoundation on FreeBSD instead of plain `trunkmaster/apple-corefoundation`.

## Why

trunkmaster's CF carries its own `CFFileDescriptor` implementation (its
commit "Added implementation of CFFileDescriptor", patch 0002 in its series).
On FreeBSD that implementation busy-spins: its libdispatch `READ` source on
the X11 connection fd re-signals the CFRunLoop source every pass, so
`__CFRunLoopRun` never reaches its blocking wait (`__CFRunLoopDoSources0`
runs ~1M×/s). Workspace pegs a core at idle.

## What is built instead

1. Base: `swiftlang/swift-corelibs-foundation` at `swift-5.10.1-RELEASE`,
   its `CoreFoundation/` subtree, plus the FreeBSD ports(7) CF patches
   (`patches/patch-swift-corelibs-foundation_CoreFoundation_*`, vendored from
   `lang/swift510`). This base carries the working BSD `CFRunLoop` /
   `CFFileDescriptor` path.
2. trunkmaster's own edits (`dbca8c7d..9e27fa55`) layered on top with
   `git apply --reject`, **minus** `0002-Added-implementation-of-CFFileDescriptor`.
3. `patches/0001-CoreFoundation_RunLoop.subproj_CFFileDescriptor.h.patch` —
   widens the CFFileDescriptor.h guard to `TARGET_OS_BSD`.

This mirrors the CoreFoundation that `developer-release-1.03` ships (its
`Installer/FreeBSD/1_build_libcorefoundation.sh`). This adaptation differs
deliberately in two ways: it sources the base from the release tarball +
vendored patches rather than driving the full `lang/swift510` port through
`bsdmake patch`, and it does NOT rebuild/reinstall libdispatch (the existing
stage-0 libdispatch is kept, so the main-queue drainer fix is undisturbed).

## Interrupted waits and host suspend/resume

The FreeBSD CFRunLoop waits retry `kevent()` only when it returns `-1` with
`errno == EINTR`. Host resume can interrupt the blocking port-set wait;
treating every negative return as HALT previously killed Workspace with
SIGILL. A physical host core confirmed errno 4 (EINTR), rather than EBADF.
The retry applies to port-set, ready-port, and single-port waits. Other
errors retain their existing fatal handling. These calls use zero or infinite
timeouts, so retrying does not extend a finite timeout.

A focused regression uses SIGUSR1 without SA_RESTART to interrupt a real
run-loop worker, then verifies that a source callback still runs:

```sh
clang -fblocks -F/usr/local/NextSpace/Frameworks \
  -I/usr/local/NextSpace/include \
  Libraries/libcorefoundation/freebsd/tests/runloop-eintr.c \
  -L/usr/local/NextSpace/lib -lCoreFoundation -ldispatch -lpthread -lm \
  -o /tmp/runloop-eintr
env LD_LIBRARY_PATH=/usr/local/NextSpace/lib:/Library/Libraries \
  timeout 10 /tmp/runloop-eintr
```

Unfixed libraries exit on SIGILL; fixed libraries report 25 signals,
1 callback, handled-source result 4, and exit 0. A CF worker thread teardown
warning may also be emitted. Physical host verification additionally confirmed
that the same Workspace process survived S3 suspend/resume and passed window
mapping, resizing and keyboard-focus checks afterward.

## Prefix note

The current FreeBSD Packaging build uses `/usr/local/NextSpace`, with
GNUstep local-domain libraries under `/Library/Libraries`.

## Deadline timers and idle CPU

FreeBSD kqueue NOTE_ABSTIME uses a different epoch from the CLOCK_UPTIME
nanoseconds returned by this build of mach_absolute_time. Passing a CF deadline
directly makes it immediately expired. In addition, an absolute timer registered
without EV_ONESHOT remains readable after delivery. Once the last CF timer has
fired, its port can therefore spin a whole core despite having no timers left.

The supplemental 0002 patch converts the uptime deadline to a relative
nanosecond delay (minimum one nanosecond, capped at INT64_MAX) and registers
EV_ADD | EV_ONESHOT without NOTE_ABSTIME. Future repeating CF timers continue to
rearm explicitly. Linux and other platforms are unchanged.

On the live host the expired timer produced 1,273,251 identical events in three
seconds. The standalone timer test produced 64 repeated deliveries with the old
flags versus one with EV_ONESHOT. The CF regression exercises one one-shot and
three repeating callbacks, then keeps the loop alive to check for idle spin:
147,300 wakeups and 0.249801 CPU seconds before; five wakeups and 0.000702 CPU
seconds after, over a quarter-second run.

Build tests with the installed development headers and libraries:

    clang tests/absolute-timer.c -o /tmp/absolute-timer
    /tmp/absolute-timer
    clang -fblocks -F/usr/local/NextSpace/Frameworks -I/usr/local/NextSpace/include \
        tests/timer-idle.c -L/usr/local/NextSpace/lib -lCoreFoundation -ldispatch \
        -lpthread -lm -o /tmp/timer-idle
    env LD_LIBRARY_PATH=/usr/local/NextSpace/lib:/Library/Libraries /tmp/timer-idle

Run the commands above from Libraries/libcorefoundation/freebsd.
