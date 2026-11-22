--- swift-corelibs-libdispatch/src/apply.c.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/apply.c
@@ -363,6 +363,6 @@ dispatch_apply(size_t iterations, dispatch_queue_t dq,
 dispatch_apply(size_t iterations, dispatch_queue_t dq, void (^work)(size_t))
 {
 	dispatch_apply_f(iterations, dq, work,
-			(dispatch_apply_function_t)_dispatch_Block_invoke(work));
+			(dispatch_apply_function_t)(void *)_dispatch_Block_invoke(work));
 }
 #endif
