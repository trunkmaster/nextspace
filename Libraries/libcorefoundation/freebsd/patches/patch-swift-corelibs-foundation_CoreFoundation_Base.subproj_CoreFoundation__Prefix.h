--- swift-corelibs-foundation/CoreFoundation/Base.subproj/CoreFoundation_Prefix.h.orig	2024-05-31 00:46:27 UTC
+++ swift-corelibs-foundation/CoreFoundation/Base.subproj/CoreFoundation_Prefix.h
@@ -260,6 +260,10 @@ CF_INLINE uint64_t mach_absolute_time() {
     ULONGLONG ullTime;
 	QueryUnbiasedInterruptTimePrecise(&ullTime);
     return ullTime;
+#elif defined(__FreeBSD__)
+    struct timespec ts;
+    clock_gettime(CLOCK_UPTIME, &ts);
+    return (uint64_t)ts.tv_nsec + (uint64_t)ts.tv_sec * 1000000000UL;
 #elif TARGET_OS_LINUX || TARGET_OS_BSD || TARGET_OS_MAC
     struct timespec ts;
     clock_gettime(CLOCK_MONOTONIC, &ts);
