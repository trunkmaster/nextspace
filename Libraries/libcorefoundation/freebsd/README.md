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
