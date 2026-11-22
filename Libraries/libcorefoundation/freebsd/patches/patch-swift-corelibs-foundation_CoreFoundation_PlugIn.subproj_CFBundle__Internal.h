--- swift-corelibs-foundation/CoreFoundation/PlugIn.subproj/CFBundle_Internal.h.orig	2024-05-31 00:46:27 UTC
+++ swift-corelibs-foundation/CoreFoundation/PlugIn.subproj/CFBundle_Internal.h
@@ -429,7 +429,7 @@ static bool _CFGetPathFromFileDescriptor(int fd, char 
 // The buffer must be PATH_MAX long or more.
 static bool _CFGetPathFromFileDescriptor(int fd, char *path);
 
-#if TARGET_OS_MAC || (TARGET_OS_BSD && !defined(__OpenBSD__))
+#if TARGET_OS_MAC
 
 static bool _CFGetPathFromFileDescriptor(int fd, char *path) {
     return fcntl(fd, F_GETPATH, path) != -1;
