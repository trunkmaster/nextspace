--- swift-corelibs-libdispatch/tests/bsdtestharness.c.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/tests/bsdtestharness.c
@@ -20,6 +20,7 @@
 
 #include <dispatch/dispatch.h>
 #include <assert.h>
+#include <inttypes.h>
 #include <stdio.h>
 #include <stdlib.h>
 #if defined(__unix__) || (defined(__APPLE__) && defined(__MACH__))
@@ -211,7 +212,7 @@ main(int argc, char *argv[])
 #else
 	dispatch_queue_t main_q = dispatch_get_main_queue();
 
-	dispatch_source_t tmp_ds = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, pid, DISPATCH_PROC_EXIT, main_q);
+	dispatch_source_t tmp_ds = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, (uintptr_t)pid, DISPATCH_PROC_EXIT, main_q);
 	assert(tmp_ds);
 	dispatch_source_set_event_handler(tmp_ds, ^{
 		int status;
@@ -221,14 +222,22 @@ main(int argc, char *argv[])
 		gettimeofday(&tv_stop, NULL);
 		tv_wall.tv_sec = tv_stop.tv_sec - tv_start.tv_sec;
 		tv_wall.tv_sec -= (tv_stop.tv_usec < tv_start.tv_usec);
+#if defined(__FreeBSD__)
+		tv_wall.tv_usec = labs(tv_stop.tv_usec - tv_start.tv_usec);
+#else
 		tv_wall.tv_usec = abs(tv_stop.tv_usec - tv_start.tv_usec);
+#endif
 
 		int res2 = wait4(pid, &status, 0, &usage);
+#ifdef NDEBUG
+		(void)res2;
+#else
 		assert(res2 != -1);
+#endif
 		test_long("Process exited", (WIFEXITED(status) && WEXITSTATUS(status) && WEXITSTATUS(status) != 0xff) || WIFSIGNALED(status), 0);
-		printf("[PERF]\twall time: %ld.%06d\n", tv_wall.tv_sec, tv_wall.tv_usec);
-		printf("[PERF]\tuser time: %ld.%06d\n", usage.ru_utime.tv_sec, usage.ru_utime.tv_usec);
-		printf("[PERF]\tsystem time: %ld.%06d\n", usage.ru_stime.tv_sec, usage.ru_stime.tv_usec);
+		printf("[PERF]\twall time: %ld.%06" PRId64 "\n", tv_wall.tv_sec, (int64_t)tv_wall.tv_usec);
+		printf("[PERF]\tuser time: %ld.%06" PRId64 "\n", usage.ru_utime.tv_sec, (int64_t)usage.ru_utime.tv_usec);
+		printf("[PERF]\tsystem time: %ld.%06" PRId64 "\n", usage.ru_stime.tv_sec, (int64_t)usage.ru_stime.tv_usec);
 		printf("[PERF]\tmax resident set size: %ld\n", usage.ru_maxrss);
 		printf("[PERF]\tpage faults: %ld\n", usage.ru_majflt);
 		printf("[PERF]\tswaps: %ld\n", usage.ru_nswap);
@@ -253,7 +262,7 @@ main(int argc, char *argv[])
 #endif
 	}
 
-	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, to), main_q, ^{
+	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)to), main_q, ^{
 		kill(pid, SIGKILL);
 		fprintf(stderr, "Terminating unresponsive process (%0.1lfs)\n", (double)to / NSEC_PER_SEC);
 	});
@@ -267,9 +276,13 @@ main(int argc, char *argv[])
 	});
 	dispatch_resume(tmp_ds);
 
+#ifdef HAVE_POSIX_SPAWNP
+#ifdef __APPLE__
 	if (spawnflags & POSIX_SPAWN_SETEXEC) {
 		usleep(USEC_PER_SEC/10);
 	}
+#endif
+#endif
 	kill(pid, SIGCONT);
 
 	dispatch_main();
