--- swift-corelibs-libdispatch/src/event/workqueue_internal.h.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/event/workqueue_internal.h
@@ -30,7 +30,7 @@ void _dispatch_workq_worker_unregister(dispatch_queue_
 void _dispatch_workq_worker_register(dispatch_queue_global_t root_q);
 void _dispatch_workq_worker_unregister(dispatch_queue_global_t root_q);
 
-#if defined(__linux__) || defined(_WIN32)
+#if defined(__linux__) || defined(__FreeBSD__) || defined(_WIN32)
 #define HAVE_DISPATCH_WORKQ_MONITORING 1
 #else
 #define HAVE_DISPATCH_WORKQ_MONITORING 0
