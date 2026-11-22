--- swift-corelibs-foundation/CoreFoundation/RunLoop.subproj/CFRunLoop.c.orig	2024-05-31 00:46:27 UTC
+++ swift-corelibs-foundation/CoreFoundation/RunLoop.subproj/CFRunLoop.c
@@ -115,6 +115,15 @@ extern void _dispatch_main_queue_callback_4CF(void *_N
 dispatch_runloop_handle_t _dispatch_get_main_queue_port_4CF(void);
 extern void _dispatch_main_queue_callback_4CF(void *_Null_unspecified msg);
 
+#elif defined(__FreeBSD__)
+
+#include <sys/event.h>
+#include <errno.h>
+#include <dlfcn.h>
+
+extern dispatch_runloop_handle_t _dispatch_get_main_queue_port_4CF(void);
+extern void _dispatch_main_queue_callback_4CF(void *_Null_unspecified msg);
+
 #else
 dispatch_runloop_handle_t _dispatch_get_main_queue_port_4CF(void);
 extern void _dispatch_main_queue_callback_4CF(void *_Null_unspecified msg);
@@ -451,6 +460,98 @@ CF_INLINE void __CFPortSetFree(__CFPortSet portSet) {
 CF_INLINE void __CFPortSetFree(__CFPortSet portSet) {
     close(portSet);
 }
+
+#elif defined(__FreeBSD__)
+
+// A file descriptor.
+typedef int __CFPort;
+// A timer port is a kqueue which monitors a single EVFILT_TIMER event (when the timer is armed).
+// A wakeup port is a kqueue which monitors a single EVFILT_USER event.
+
+#define CFPORT_NULL (-1)
+
+// A kqueue file descriptor.
+typedef int __CFPortSet;
+
+#define CFPORTSET_NULL (-1)
+
+
+static void __THE_SYSTEM_HAS_NO_PORTS_AVAILABLE__(kern_return_t ret) __attribute__((noinline));
+static void __THE_SYSTEM_HAS_NO_PORTS_AVAILABLE__(kern_return_t ret) { HALT; };
+
+static __CFPort __CFPortAllocate(uintptr_t guard) {
+    __CFPort kq = kqueuex(KQUEUE_CLOEXEC);
+    if (kq == -1) {
+        __THE_SYSTEM_HAS_NO_PORTS_AVAILABLE__(errno);
+        return CFPORT_NULL;
+    }
+    struct kevent kev = {
+        .ident = 0,
+        .filter = EVFILT_USER,
+        .flags = EV_ADD | EV_CLEAR,
+    };
+    int r = kevent(kq, &kev, 1, NULL, 0, NULL);
+    if (r == -1) {
+	HALT;
+        return CFPORT_NULL;
+    }
+    return kq;
+}
+
+static void __CFPortFree(__CFPort port, uintptr_t guard) {
+    close(port);
+}
+
+static void __THE_SYSTEM_HAS_NO_PORT_SETS_AVAILABLE__(kern_return_t ret) __attribute__((noinline));
+static void __THE_SYSTEM_HAS_NO_PORT_SETS_AVAILABLE__(kern_return_t ret) { HALT; }
+
+static __CFPortSet __CFPortSetAllocate(void) {
+    __CFPort kq = kqueuex(KQUEUE_CLOEXEC);
+    if (kq == -1) {
+        __THE_SYSTEM_HAS_NO_PORT_SETS_AVAILABLE__(errno);
+        return CFPORT_NULL;
+    }
+    return kq;
+}
+
+static kern_return_t __CFPortSetInsert(__CFPort port, __CFPortSet portSet) {
+    if (port == CFPORT_NULL) {
+        return -1;
+    }
+    struct kevent kev = {
+        .ident = (uintptr_t)port,
+        .filter = EVFILT_READ,
+        .flags = EV_ADD,
+    };
+    int r = kevent(portSet, &kev, 1, NULL, 0, NULL);
+    if (r == -1) {
+        return errno;
+    } else {
+        return 0;
+    }
+}
+
+static kern_return_t __CFPortSetRemove(__CFPort port, __CFPortSet portSet) {
+    if (port == CFPORT_NULL) {
+        return -1;
+    }
+    struct kevent kev = {
+        .ident = (uintptr_t)port,
+        .filter = EVFILT_READ,
+        .flags = EV_DELETE,
+    };
+    int r = kevent(portSet, &kev, 1, NULL, 0, NULL);
+    if (r == -1) {
+        return errno;
+    } else {
+        return 0;
+    }
+}
+
+static void __CFPortSetFree(__CFPortSet portSet) {
+    close(portSet);
+}
+
 #elif TARGET_OS_BSD
 
 #include <sys/types.h>
@@ -823,6 +924,58 @@ static kern_return_t mk_timer_cancel(HANDLE name, Abso
     }
     return (int)res;
 }
+#elif defined(__FreeBSD__)
+static __CFPort mk_timer_create(void) {
+    __CFPort kq = kqueuex(KQUEUE_CLOEXEC);
+    if (kq == -1) {
+        HALT;
+        return CFPORT_NULL;
+    }
+    return kq;
+}
+
+static kern_return_t mk_timer_destroy(__CFPort name) {
+    return close(name);
+}
+
+static kern_return_t mk_timer_cancel(__CFPort timer, AbsoluteTime *result_time) {
+    struct kevent kev = {
+        .ident = 0,
+        .filter = EVFILT_TIMER,
+        .flags = EV_DELETE,
+    };
+    int r = kevent(timer, &kev, 1, NULL, 0, NULL);
+    // The returned values are ignored.
+    *result_time = (struct UnsignedWide){ .hi = 0, .lo = 0 };
+    return 0;
+}
+
+static kern_return_t mk_timer_arm(__CFPort timer, uint64_t expire_time) {
+    struct kevent kev = {
+        .ident = 0,
+        .filter = EVFILT_TIMER,
+        .flags = EV_ADD,
+        .fflags = NOTE_NSECONDS | NOTE_ABSTIME,
+        .data = (int64_t)expire_time,
+    };
+    int r = kevent(timer, &kev, 1, NULL, 0, NULL);
+    // The returned value is ignored.
+    return 0;
+}
+
+static Boolean __CFPortTriggerWakeup(__CFPort wakeupPort) {
+    struct kevent kev = {
+        .ident = 0,
+        .filter = EVFILT_USER,
+        .fflags = NOTE_TRIGGER,
+    };
+    int r = kevent(wakeupPort, &kev, 1, NULL, 0, NULL);
+    if (r == -1) {
+        return false;
+    } else {
+        return true;
+    }
+}
 #elif TARGET_OS_BSD
 /*
  * This implementation of the mk_timer_* stubs is defined with the
@@ -1136,7 +1289,7 @@ static CFRunLoopModeRef __CFRunLoopCopyMode(CFRunLoopR
     if (KERN_SUCCESS != ret) CRASH("*** Unable to insert timer port into port set. (%d) ***", ret);
 #endif
     rlm->_timerPort = CFPORT_NULL;
-#if TARGET_OS_BSD
+#if TARGET_OS_BSD && !defined(__FreeBSD__)
     rlm->_timerPort = mk_timer_create(rlm->_portSet);
 #else
     rlm->_timerPort = mk_timer_create();
@@ -2412,7 +2565,7 @@ static void __CFArmNextTimerInMode(CFRunLoopModeRef rl
                 // <rdar://problem/14447675>
                 
                 // Cancel the mk timer
-                if (rlm->_mkTimerArmed && rlm->_timerPort) {
+                if (rlm->_mkTimerArmed && rlm->_timerPort != CFPORT_NULL) {
                     AbsoluteTime dummy;
                     mk_timer_cancel(rlm->_timerPort, &dummy);
                     rlm->_mkTimerArmed = false;
@@ -2430,20 +2583,20 @@ static void __CFArmNextTimerInMode(CFRunLoopModeRef rl
                 }
                 
                 // Arm the mk timer
-                if (rlm->_timerPort) {
+                if (rlm->_timerPort != CFPORT_NULL) {
                     mk_timer_arm(rlm->_timerPort, nextSoftDeadline);
                     rlm->_mkTimerArmed = true;
                 }
             }
 #else
-            if (rlm->_timerPort) {
+            if (rlm->_timerPort != CFPORT_NULL) {
                 mk_timer_arm(rlm->_timerPort, nextSoftDeadline);
             }
 #endif
         } else if (nextSoftDeadline == UINT64_MAX) {
             // Disarm the timers - there is no timer scheduled
             
-            if (rlm->_mkTimerArmed && rlm->_timerPort) {
+            if (rlm->_mkTimerArmed && rlm->_timerPort != CFPORT_NULL) {
                 AbsoluteTime dummy;
                 mk_timer_cancel(rlm->_timerPort, &dummy);
                 rlm->_mkTimerArmed = false;
@@ -2916,6 +3069,65 @@ static Boolean __CFRunLoopWaitForMultipleObjects(__CFP
     return result;
 }
 
+#elif defined(__FreeBSD__)
+
+#define TIMEOUT_INFINITY (-1)
+
+static Boolean __CFRunLoopServicePorts(__CFPortSet portSet, __CFPort singlePort, __CFPort *livePort, int timeout) {
+    *livePort = CFPORT_NULL;
+    if (TIMEOUT_INFINITY == timeout) {
+        CFRUNLOOP_SLEEP();
+    } else {
+        CFRUNLOOP_POLL();
+    }
+    const struct timespec poll_ts = { .tv_sec = 0, .tv_nsec = 0 };
+    struct kevent kev;
+    if (portSet != CFPORTSET_NULL) {
+        // Find out which port has an event waiting.
+        int r;
+        do {
+            r = kevent(portSet, NULL, 0, &kev, 1, (timeout == TIMEOUT_INFINITY) ? NULL : &poll_ts);
+        } while (r == -1 && errno == EINTR);
+        CFRUNLOOP_WAKEUP(r);
+        if (r == 1) {
+            int kq2 = (int)kev.ident;
+            // Receive the event.
+            int r2;
+            do {
+                r2 = kevent(kq2, NULL, 0, &kev, 1, &poll_ts);
+            } while (r2 == -1 && errno == EINTR);
+            if (r2 == 1) {
+                *livePort = kq2;
+                return true;
+            } else if (r2 == 0) {
+                return false;
+            } else {
+                HALT;
+                return false;
+            }
+        } else if (r == 0) {
+            return false;
+        } else {
+            HALT;
+            return false;
+        }
+    } else {
+        int r;
+        do {
+            r = kevent(singlePort, NULL, 0, &kev, 1, (timeout == TIMEOUT_INFINITY) ? NULL : &poll_ts);
+        } while (r == -1 && errno == EINTR);
+        CFRUNLOOP_WAKEUP(r);
+        if (r == 1) {
+            *livePort = singlePort;
+            return true;
+        } else if (r == 0) {
+            return false;
+        } else {
+            HALT;
+            return false;
+        }
+    }
+}
 #endif
 
 /* rl, rlm are locked on entrance and exit */
@@ -3034,6 +3246,10 @@ static int32_t __CFRunLoopRun(CFRunLoopRef rl, CFRunLo
             if (__CFRunLoopWaitForMultipleObjects(NULL, &dispatchPort, 0, 0, &livePort, NULL)) {
                 goto handle_msg;
             }
+#elif defined(__FreeBSD__)
+            if (__CFRunLoopServicePorts(CFPORTSET_NULL, dispatchPort, &livePort, 0)) {
+                goto handle_msg;
+            }
 #elif TARGET_OS_BSD
             if (__CFRunLoopServiceFileDescriptors(CFPORTSET_NULL, dispatchPort, 0, &livePort)) {
                 goto handle_msg;
@@ -3095,6 +3311,8 @@ static int32_t __CFRunLoopRun(CFRunLoopRef rl, CFRunLo
         __CFRunLoopWaitForMultipleObjects(waitSet, NULL, poll ? 0 : TIMEOUT_INFINITY, rlm->_msgQMask, &livePort, &windowsMessageReceived);
 #elif TARGET_OS_LINUX
         __CFRunLoopServiceFileDescriptors(waitSet, CFPORT_NULL, poll ? 0 : TIMEOUT_INFINITY, &livePort);
+#elif defined(__FreeBSD__)
+        __CFRunLoopServicePorts(waitSet, CFPORT_NULL, &livePort, poll ? 0 : TIMEOUT_INFINITY);
 #elif TARGET_OS_BSD
         __CFRunLoopServiceFileDescriptors(waitSet, CFPORT_NULL, poll ? 0 : TIMEOUT_INFINITY, &livePort);
 #else
@@ -3406,6 +3624,9 @@ void CFRunLoopWakeUp(CFRunLoopRef rl) {
     CFAssert1(0 == ret, __kCFLogAssertion, "%s(): Unable to send wake message to eventfd", __PRETTY_FUNCTION__);
 #elif TARGET_OS_WIN32
     SetEvent(rl->_wakeUpPort);
+#elif defined(__FreeBSD__)
+    Boolean success = __CFPortTriggerWakeup(rl->_wakeUpPort);
+    if (!success) HALT;
 #elif TARGET_OS_BSD
     __CFPortTrigger(rl->_wakeUpPort);
 #else
@@ -4131,6 +4352,10 @@ CFRunLoopSourceRef CFRunLoopSourceCreate(CFAllocatorRe
 	size = sizeof(CFRunLoopSourceContext);
 	break;
     case 1:
+#if defined(__FreeBSD__)
+	// V1 sources are not implemented on FreeBSD yet
+	HALT;
+#endif
 	size = sizeof(CFRunLoopSourceContext1);
 	break;
     }
@@ -4275,7 +4500,7 @@ static CFStringRef __CFRunLoopObserverCopyDescription(
     }
 #if TARGET_OS_WIN32
     result = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("<CFRunLoopObserver %p [%p]>{valid = %s, activities = 0x%x, repeats = %s, order = %d, callout = %p, context = %@}"), cf, CFGetAllocator(rlo), __CFIsValid(rlo) ? "Yes" : "No", rlo->_activities, __CFRunLoopObserverRepeats(rlo) ? "Yes" : "No", rlo->_order, rlo->_callout, contextDesc);    
-#elif TARGET_OS_MAC || (TARGET_OS_LINUX && !TARGET_OS_CYGWIN)
+#elif TARGET_OS_MAC || (TARGET_OS_LINUX && !TARGET_OS_CYGWIN) || defined(__FreeBSD__)
     void *addr = rlo->_callout;
     Dl_info info;
     const char *name = (dladdr(addr, &info) && info.dli_saddr == addr && info.dli_sname) ? info.dli_sname : "???";
