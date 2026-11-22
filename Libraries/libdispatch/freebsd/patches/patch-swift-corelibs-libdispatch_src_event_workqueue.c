--- swift-corelibs-libdispatch/src/event/workqueue.c.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/event/workqueue.c
@@ -22,6 +22,14 @@
 
 #if DISPATCH_USE_INTERNAL_WORKQUEUE
 
+#if defined(__FreeBSD__)
+#include <stdlib.h>
+#include <unistd.h>
+#include <sys/param.h>
+#include <sys/sysctl.h>
+#include <sys/user.h>
+#endif
+
 #if defined(_WIN32)
 #include <wct.h>
 #endif
@@ -31,7 +39,7 @@
  * executing the work enqueued on libdispatch's pthread
  * root queues and dynamically adjusts its size.
  *
- * The dynamic monitoring could be implemented using either
+ * The dynamic monitoring could be implemented on Linux using either
  *   (a) low-frequency user-level approximation of the number of runnable
  *       worker threads via reading the /proc file system
  *   (b) a Linux kernel extension that hooks the process change handler
@@ -183,6 +191,79 @@ _dispatch_workq_count_runnable_workers(dispatch_workq_
 	mon->num_runnable = running_count;
 
 	_dispatch_unfair_lock_unlock(&mon->registered_tid_lock);
+}
+#elif defined(__FreeBSD__)
+/*
+ * Count the number of runnable worker threads by obtaining information about
+ * all threads in the current process by means of sysctl().
+ * Because the caller expects that we always compute num_runnable, we always
+ * compute a value, even when we can't really compute the correct value.
+ */
+static void
+_dispatch_workq_count_runnable_workers(dispatch_workq_monitor_t mon)
+{
+	int runnable_count = 0;
+	int pid = (int)getpid();
+	int mib[] = {CTL_KERN, KERN_PROC, (KERN_PROC_PID | KERN_PROC_INC_THREAD), pid};
+	size_t oldlen = 0;
+	struct kinfo_proc *buf = NULL;
+	int r;
+
+	// Find out what size of buffer we need.
+	r = sysctl(mib, nitems(mib), NULL, &oldlen, NULL, 0);
+	if (r == -1) {
+		goto fail;
+	}
+
+	buf = malloc(oldlen);
+	if (buf == NULL) {
+		goto fail;
+	}
+
+	/*
+	 * Note: Between the previous sysctl() call and this call the number of
+	 * threads in the process might have increased and thus the buffer
+	 * might be too small to actually accomodate all threads.
+	 */
+	r = sysctl(mib, nitems(mib), buf, &oldlen, NULL, 0);
+	if (r == -1 && errno != ENOMEM) {
+		goto fail;
+	}
+
+	int n_all_threads = (int)(oldlen / sizeof(struct kinfo_proc));
+
+	// Verify that our idea of sizeof(struct kinfo_proc) matches the kernel's.
+	if (n_all_threads > 0) {
+		if (buf[0].ki_structsize != sizeof(struct kinfo_proc)) {
+			goto fail;
+		}
+	}
+
+	_dispatch_unfair_lock_lock(&mon->registered_tid_lock);
+
+	for (int i = 0; i < mon->num_registered_tids; i++) {
+		dispatch_tid tid = mon->registered_tids[i];
+		for (int j = 0; j < n_all_threads; j++) {
+			if ((dispatch_tid)buf[j].ki_tid == tid) {
+				if (buf[j].ki_stat == SRUN) {
+					runnable_count++;
+				}
+				break;
+			}
+		}
+	}
+
+	mon->num_runnable = runnable_count;
+
+	_dispatch_unfair_lock_unlock(&mon->registered_tid_lock);
+
+	free(buf);
+	return;
+
+	fail: _dispatch_unfair_lock_lock(&mon->registered_tid_lock);
+	mon->num_runnable = runnable_count;
+	_dispatch_unfair_lock_unlock(&mon->registered_tid_lock);
+	free(buf);
 }
 #elif defined(_WIN32)
 static void
