--- swift-corelibs-libdispatch/dispatch/source.h.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/dispatch/source.h
@@ -116,7 +116,7 @@ DISPATCH_SOURCE_TYPE_DECL(data_replace);
  * The mask is a mask of desired events from dispatch_source_mach_send_flags_t.
  */
 #define DISPATCH_SOURCE_TYPE_MACH_SEND (&_dispatch_source_type_mach_send)
-API_AVAILABLE(macos(10.6), ios(4.0)) DISPATCH_LINUX_UNAVAILABLE()
+API_AVAILABLE(macos(10.6), ios(4.0)) DISPATCH_LINUX_UNAVAILABLE() DISPATCH_FREEBSD_UNAVAILABLE()
 DISPATCH_SOURCE_TYPE_DECL(mach_send);
 
 /*!
@@ -126,7 +126,7 @@ DISPATCH_SOURCE_TYPE_DECL(mach_send);
  * The mask is unused (pass zero for now).
  */
 #define DISPATCH_SOURCE_TYPE_MACH_RECV (&_dispatch_source_type_mach_recv)
-API_AVAILABLE(macos(10.6), ios(4.0)) DISPATCH_LINUX_UNAVAILABLE()
+API_AVAILABLE(macos(10.6), ios(4.0)) DISPATCH_LINUX_UNAVAILABLE() DISPATCH_FREEBSD_UNAVAILABLE()
 DISPATCH_SOURCE_TYPE_DECL(mach_recv);
 
 /*!
@@ -139,7 +139,7 @@ DISPATCH_SOURCE_TYPE_DECL(mach_recv);
  */
 #define DISPATCH_SOURCE_TYPE_MEMORYPRESSURE \
 		(&_dispatch_source_type_memorypressure)
-API_AVAILABLE(macos(10.9), ios(8.0)) DISPATCH_LINUX_UNAVAILABLE()
+API_AVAILABLE(macos(10.9), ios(8.0)) DISPATCH_LINUX_UNAVAILABLE() DISPATCH_FREEBSD_UNAVAILABLE()
 DISPATCH_SOURCE_TYPE_DECL(memorypressure);
 
 /*!
