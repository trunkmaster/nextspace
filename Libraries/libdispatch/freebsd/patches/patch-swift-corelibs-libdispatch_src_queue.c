--- swift-corelibs-libdispatch/src/queue.c.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/queue.c
@@ -6467,7 +6467,7 @@ _dispatch_runloop_handle_is_valid(dispatch_runloop_han
 {
 #if TARGET_OS_MAC
 	return MACH_PORT_VALID(handle);
-#elif defined(__linux__)
+#elif defined(__linux__) || defined(__FreeBSD__)
 	return handle >= 0;
 #elif defined(_WIN32)
 	return handle != NULL;
@@ -6482,7 +6482,7 @@ _dispatch_runloop_queue_get_handle(dispatch_lane_t dq)
 {
 #if TARGET_OS_MAC
 	return ((dispatch_runloop_handle_t)(uintptr_t)dq->do_ctxt);
-#elif defined(__linux__)
+#elif defined(__linux__) || defined(__FreeBSD__)
 	// decode: 0 is a valid fd, so offset by 1 to distinguish from NULL
 	return ((dispatch_runloop_handle_t)(uintptr_t)dq->do_ctxt) - 1;
 #elif defined(_WIN32)
@@ -6499,7 +6499,7 @@ _dispatch_runloop_queue_set_handle(dispatch_lane_t dq,
 {
 #if TARGET_OS_MAC
 	dq->do_ctxt = (void *)(uintptr_t)handle;
-#elif defined(__linux__)
+#elif defined(__linux__) || defined(__FreeBSD__)
 	// encode: 0 is a valid fd, so offset by 1 to distinguish from NULL
 	dq->do_ctxt = (void *)(uintptr_t)(handle + 1);
 #elif defined(_WIN32)
@@ -6558,6 +6558,37 @@ _dispatch_runloop_queue_handle_init(void *ctxt)
 		}
 	}
 	handle = fd;
+#elif defined(__FreeBSD__)
+	int kq = kqueuex(KQUEUE_CLOEXEC);
+	if (kq == -1) {
+		int err = errno;
+		switch (err) {
+		case EMFILE:
+			DISPATCH_CLIENT_CRASH(err, "kqueuex() failure: "
+					"process is out of file descriptors");
+			break;
+		case ENFILE:
+			DISPATCH_CLIENT_CRASH(err, "kqueuex() failure: "
+					"system is out of file descriptors");
+			break;
+		case ENOMEM:
+			DISPATCH_CLIENT_CRASH(err, "kqueuex() failure: "
+					"kernel is out of memory or the "
+					"RLIMIT_KQUEUES user resource limit "
+					"would be exceeded");
+			break;
+		default:
+			DISPATCH_INTERNAL_CRASH(err, "kqueuex() failure");
+			break;
+		}
+	}
+	struct kevent kev = {
+		.ident = 0, // Must match the value used by Core Foundation.
+		.filter = EVFILT_USER,
+		.flags = EV_ADD | EV_CLEAR,
+	};
+	dispatch_assume_zero(kevent(kq, &kev, 1, NULL, 0, NULL));
+	handle = kq;
 #elif defined(_WIN32)
 	HANDLE hEvent;
 	hEvent = CreateEventW(NULL, /*bManualReset=*/FALSE,
@@ -6589,7 +6620,7 @@ _dispatch_runloop_queue_handle_dispose(dispatch_lane_t
 	kr = mach_port_destruct(mach_task_self(), mp, -1, guard);
 	DISPATCH_VERIFY_MIG(kr);
 	(void)dispatch_assume_zero(kr);
-#elif defined(__linux__)
+#elif defined(__linux__) || defined(__FreeBSD__)
 	int rc = close(handle);
 	(void)dispatch_assume_zero(rc);
 #elif defined(_WIN32)
@@ -6628,6 +6659,13 @@ _dispatch_runloop_queue_class_poke(dispatch_lane_t dq)
 		result = eventfd_write(handle, 1);
 	} while (result == -1 && errno == EINTR);
 	(void)dispatch_assume_zero(result);
+#elif defined(__FreeBSD__)
+	struct kevent kev = {
+		.ident = 0, // Must match the value used by Core Foundation.
+		.filter = EVFILT_USER,
+		.fflags = NOTE_TRIGGER,
+	};
+	dispatch_assume_zero(kevent(handle, &kev, 1, NULL, 0, NULL));
 #elif defined(_WIN32)
 	BOOL bSuccess;
 	bSuccess = SetEvent(handle);
