--- swift-corelibs-libdispatch/src/data.c.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/data.c
@@ -600,7 +600,7 @@ dispatch_data_apply(dispatch_data_t dd, dispatch_data_
 		return true;
 	}
 	return _dispatch_data_apply(dd, 0, 0, dd->size, applier,
-			(dispatch_data_applier_function_t)_dispatch_Block_invoke(applier));
+			(dispatch_data_applier_function_t)(void *)_dispatch_Block_invoke(applier));
 }
 
 static dispatch_data_t
