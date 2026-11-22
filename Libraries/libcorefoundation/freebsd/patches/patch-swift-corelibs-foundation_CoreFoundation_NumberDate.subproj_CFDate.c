--- swift-corelibs-foundation/CoreFoundation/NumberDate.subproj/CFDate.c.orig	2024-05-31 00:46:27 UTC
+++ swift-corelibs-foundation/CoreFoundation/NumberDate.subproj/CFDate.c
@@ -176,6 +176,10 @@ CF_PRIVATE void __CFDateInitialize(void) {
     // To get seconds we need to divide the value by 1e7 (10000000).
     __CFTSRRate = 1.0e7;
     __CF1_TSRRate = 1.0 / __CFTSRRate;
+#elif defined(__FreeBSD__)
+    // FreeBSD uses nanoseconds
+    __CFTSRRate = 1.0E9;
+    __CF1_TSRRate = 1.0 / __CFTSRRate;
 #elif TARGET_OS_LINUX || TARGET_OS_BSD || TARGET_OS_WASI
     struct timespec res;
     if (clock_getres(CLOCK_MONOTONIC, &res) != 0) {
