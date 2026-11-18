--- swift-corelibs-libdispatch/src/shims/lock.h.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/shims/lock.h
@@ -79,6 +79,25 @@ _dispatch_lock_owner(dispatch_lock lock_value)
 	return lock_value & DLOCK_OWNER_MASK;
 }
 
+#elif defined(__FreeBSD__)
+
+typedef uint32_t dispatch_tid;
+typedef uint32_t dispatch_lock;
+
+#define DLOCK_OWNER_MASK			((dispatch_lock)0x3fffffff)
+#define DLOCK_WAITERS_BIT			((dispatch_lock)0x40000000)
+#define DLOCK_FAILED_TRYLOCK_BIT	((dispatch_lock)0x80000000)
+
+#define DLOCK_OWNER_NULL			((dispatch_tid)0)
+#define _dispatch_tid_self()		((dispatch_tid)pthread_getthreadid_np())
+
+DISPATCH_ALWAYS_INLINE
+static inline dispatch_tid
+_dispatch_lock_owner(dispatch_lock lock_value)
+{
+	return lock_value & DLOCK_OWNER_MASK;
+}
+
 #elif defined(_WIN32)
 
 #include <Windows.h>
