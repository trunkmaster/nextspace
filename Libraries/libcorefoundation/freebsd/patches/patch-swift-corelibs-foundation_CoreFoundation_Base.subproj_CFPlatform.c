--- swift-corelibs-foundation/CoreFoundation/Base.subproj/CFPlatform.c.orig	2024-05-31 00:46:27 UTC
+++ swift-corelibs-foundation/CoreFoundation/Base.subproj/CFPlatform.c
@@ -125,7 +125,7 @@ static inline void _CFSetProgramNameFromPath(const cha
     __CFprogname = (__CFprogname ? __CFprogname + 1 : __CFProcessPath);
 }
 
-#if TARGET_OS_BSD && defined(__OpenBSD__)
+#if TARGET_OS_BSD && (defined(__OpenBSD__) || defined(__FreeBSD__))
 #include <sys/types.h>
 #include <sys/sysctl.h>
 #include <sys/exec.h>
@@ -199,6 +199,14 @@ const char *_CFProcessPath(void) {
         struct ps_strings *ps = _ps.val;
         char *res = realpath(ps->ps_argvstr[0], NULL);
         argv0 = res? res: strdup(ps->ps_argvstr[0]);
+    }
+#elif defined(__FreeBSD__)
+    int mib[2] = {CTL_KERN, KERN_PS_STRINGS};
+    struct ps_strings *ps;
+    size_t oldlen = sizeof(ps);
+    if (sysctl(mib, 2, &ps, &oldlen, NULL, 0) != -1 && oldlen == sizeof(ps)) {
+        char *res = realpath(ps->ps_argvstr[0], NULL);
+	argv0 = (res != NULL) ? res : strdup(ps->ps_argvstr[0]);
     }
 #endif
 
