--- swift-corelibs-libdispatch/src/event/event_kevent.c.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/event/event_kevent.c
@@ -24,6 +24,9 @@
 #include "protocol.h"
 #include "protocolServer.h"
 #endif
+#if defined(__FreeBSD__)
+#include <sys/sysctl.h>
+#endif
 
 #if DISPATCH_USE_KEVENT_WORKQUEUE && !DISPATCH_USE_KEVENT_QOS
 #error unsupported configuration
@@ -50,10 +53,12 @@ DISPATCH_STATIC_GLOBAL(struct dispatch_muxnote_bucket_
 #define DISPATCH_NOTE_CLOCK_WALL      NOTE_NSECONDS | NOTE_MACH_CONTINUOUS_TIME
 #define DISPATCH_NOTE_CLOCK_MONOTONIC NOTE_MACHTIME | NOTE_MACH_CONTINUOUS_TIME
 #define DISPATCH_NOTE_CLOCK_UPTIME    NOTE_MACHTIME
+#elif defined(__FreeBSD__)
+#define DISPATCH_NOTE_CLOCK_WALL      NOTE_NSECONDS
+#define DISPATCH_NOTE_CLOCK_MONOTONIC NOTE_NSECONDS
+#define DISPATCH_NOTE_CLOCK_UPTIME    NOTE_NSECONDS
 #else
-#define DISPATCH_NOTE_CLOCK_WALL      0
-#define DISPATCH_NOTE_CLOCK_MONOTONIC 0
-#define DISPATCH_NOTE_CLOCK_UPTIME    0
+#error DISPATCH_NOTE_CLOCK_* constants not defined for this platform
 #endif
 
 static const uint32_t _dispatch_timer_index_to_fflags[] = {
@@ -388,9 +393,12 @@ _dispatch_kevent_print_error(dispatch_kevent_t ke)
 	switch (ke->data) {
 	case 0:
 		return;
+#if DISPATCH_USE_KEVENT_QOS
 	case ERANGE: /* A broken QoS was passed to kevent_id() */
 		DISPATCH_INTERNAL_CRASH(ke->qos, "Invalid kevent priority");
+#endif
 	default:
+#if HAVE_MACH
 		// log the unexpected error
 		_dispatch_bug_kevent_client("kevent", _evfiltstr(ke->filter),
 				!ke->udata ? NULL :
@@ -398,6 +406,9 @@ _dispatch_kevent_print_error(dispatch_kevent_t ke)
 				ke->flags & EV_ADD ? "add" :
 				ke->flags & EV_ENABLE ? "enable" : "monitor",
 				(int)ke->data, ke->ident, ke->udata, du);
+#else
+		(void)0;
+#endif
 	}
 }
 
@@ -591,7 +602,6 @@ _dispatch_kq_create(intptr_t *fd_ptr)
 	guardid_t guard = (uintptr_t)fd_ptr;
 	kqfd = guarded_kqueue_np(&guard, GUARD_CLOSE | GUARD_DUP);
 #else
-	(void)guard_ptr;
 	kqfd = kqueue();
 #endif
 	if (kqfd == -1) {
@@ -743,7 +753,7 @@ retry:
 		switch (err) {
 		case ENOMEM:
 			_dispatch_temporary_resource_shortage();
-			/* FALLTHROUGH */
+			DISPATCH_FALLTHROUGH;
 		case EINTR:
 			goto retry;
 		case EBADF:
@@ -754,7 +764,7 @@ retry:
 					(flags & KEVENT_FLAG_DYNAMIC_KQ_MUST_EXIST)) {
 				return 0;
 			}
-			/* FALLTHROUGH */
+			DISPATCH_FALLTHROUGH;
 #endif // DISPATCH_USE_KEVENT_WORKLOOP
 		default:
 			DISPATCH_CLIENT_CRASH(err, "Unexpected error from kevent");
@@ -860,7 +870,6 @@ _dispatch_kq_unote_set_kevent(dispatch_unote_t _du, di
 				du->du_priority),
 #endif
 	};
-	(void)pp; // if DISPATCH_USE_KEVENT_QOS == 0
 }
 
 DISPATCH_ALWAYS_INLINE
@@ -985,6 +994,7 @@ _dispatch_sync_ipc_handoff_end(dispatch_wlh_t wlh, mac
 }
 #endif
 
+#if !defined(__FreeBSD__)
 DISPATCH_NOINLINE
 static bool
 _dispatch_kq_unote_update(dispatch_wlh_t wlh, dispatch_unote_t _du,
@@ -1055,6 +1065,7 @@ done:
 	dispatch_assume_zero(r);
 	return true;
 }
+#endif
 
 #pragma mark dispatch_muxnote_t
 
@@ -1300,6 +1311,7 @@ enum {
 	DISPATCH_WORKLOOP_SYNC_END,
 };
 
+#if 0
 static char const * const _dispatch_workloop_actions[] = {
 	[DISPATCH_WORKLOOP_ASYNC]                       = "async",
 	[DISPATCH_WORKLOOP_ASYNC_FROM_SYNC]             = "async (from sync)",
@@ -1316,6 +1328,7 @@ static char const * const _dispatch_workloop_actions[]
 	[DISPATCH_WORKLOOP_SYNC_WAKE]                   = "sync-wake",
 	[DISPATCH_WORKLOOP_SYNC_END]                    = "sync-end",
 };
+#endif
 
 void
 _dispatch_event_loop_atfork_child(void)
@@ -2326,6 +2339,23 @@ _dispatch_event_loop_timer_program(dispatch_timer_heap
 	pthread_priority_t pp = _PTHREAD_PRIORITY_EVENT_MANAGER_FLAG;
 	if (wlh != DISPATCH_WLH_ANON) {
 		pp = _dispatch_qos_to_pp(dth[tidx].dth_max_qos);
+	}
+#endif
+#if defined(__FreeBSD__)
+	dispatch_clock_t clock = DISPATCH_TIMER_CLOCK(tidx);
+	if (clock == DISPATCH_CLOCK_UPTIME || clock == DISPATCH_CLOCK_MONOTONIC) {
+		/*
+		 * On FreeBSD these clocks are based on system boot time.
+		 * However, kevent() on FreeBSD accepts only values based on
+		 * the Unix epoch. For this reason we apply a correction.
+		 */
+		 static const int mib[] = { CTL_KERN, KERN_BOOTTIME };
+		 struct timeval boottime;
+		 size_t oldlen = sizeof(struct timeval);
+		 int r = sysctl(mib, 2, &boottime, &oldlen, NULL, 0);
+		 if (r == 0 && oldlen == sizeof(struct timeval)) {
+			target += _dispatch_timeval_to_nano(boottime);
+		 }
 	}
 #endif
 	dispatch_kevent_s ke = {
