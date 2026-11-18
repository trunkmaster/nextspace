--- swift-corelibs-libdispatch/src/shims/lock.c.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/shims/lock.c
@@ -19,6 +19,10 @@
  */
 
 #include "internal.h"
+#if defined(__FreeBSD__)
+#include <sys/types.h>
+#include <sys/umtx.h>
+#endif
 
 #if TARGET_OS_MAC
 dispatch_static_assert(DLOCK_LOCK_DATA_CONTENTION ==
@@ -516,6 +520,27 @@ _dispatch_wait_on_address(uint32_t volatile *_address,
 			? INFINITE : ((nsecs + 1000000) / 1000000);
 	if (dwMilliseconds == 0) return ETIMEDOUT;
 	return WaitOnAddress(address, &value, sizeof(value), dwMilliseconds) == TRUE;
+#elif defined(__FreeBSD__)
+	(void)flags;
+	if (nsecs == DISPATCH_TIME_FOREVER) {
+		_umtx_op(address, UMTX_OP_WAIT_UINT, value, NULL, NULL);
+		return 0;
+	} else {
+		struct timespec tstimeout;
+		tstimeout.tv_sec = nsecs / NSEC_PER_SEC;
+		tstimeout.tv_nsec = (long)(nsecs % NSEC_PER_SEC);
+
+		int r = _umtx_op(address, UMTX_OP_WAIT_UINT, value, (void *)(uintptr_t)sizeof(struct timespec), &tstimeout);
+		if (r == -1) {
+			if (errno == ETIMEDOUT) {
+				return ETIMEDOUT;
+			} else {
+				return 0;
+			}
+		} else {
+			return 0;
+		}
+	}
 #else
 #error _dispatch_wait_on_address unimplemented for this platform
 #endif
@@ -530,6 +555,8 @@ _dispatch_wake_by_address(uint32_t volatile *address)
 	_dispatch_futex_wake((uint32_t *)address, INT_MAX, FUTEX_PRIVATE_FLAG);
 #elif defined(_WIN32)
 	WakeByAddressAll((uint32_t *)address);
+#elif defined(__FreeBSD__)
+	_umtx_op((uint32_t *)address, UMTX_OP_WAKE, INT_MAX, NULL, NULL);
 #else
 	(void)address;
 #endif
@@ -627,7 +654,9 @@ _dispatch_unfair_lock_lock_slow(dispatch_unfair_lock_t
 		if (unlikely(_dispatch_lock_is_locked_by(cur, self))) {
 			DISPATCH_CLIENT_CRASH(0, "trying to lock recursively");
 		}
-		_dispatch_thread_switch(cur, flags, timeout++);
+		//_dispatch_thread_switch(cur, flags, timeout++);
+		(void)timeout;
+		(void)flags;
 	}
 }
 #endif
@@ -689,7 +718,7 @@ _dispatch_once_wait(dispatch_once_gate_t dgo)
 		_dispatch_futex_wait(lock, (dispatch_lock)new_v, NULL,
 				FUTEX_PRIVATE_FLAG);
 #else
-		_dispatch_thread_switch(new_v, 0, timeout++);
+		//_dispatch_thread_switch(new_v, 0, timeout++);
 #endif
 		(void)timeout;
 	}
