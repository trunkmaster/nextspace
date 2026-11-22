--- swift-corelibs-libdispatch/src/event/event_config.h.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/event/event_config.h
@@ -116,10 +116,14 @@
 #	define NOTE_FUNLOCK 0x00000100
 #	endif
 
-// FreeBSD's kevent does not support those
 #	ifndef NOTE_ABSOLUTE
-#	define NOTE_ABSOLUTE 0
+#	if defined(__FreeBSD__)
+#		define NOTE_ABSOLUTE NOTE_ABSTIME
+#	else
+#		error NOTE_ABSOLUTE must be defined for kevent-based timers to function properly
 #	endif
+#	endif
+// FreeBSD's kevent does not support NOTE_EXITSTATUS
 #	ifndef NOTE_EXITSTATUS
 #	define NOTE_EXITSTATUS 0
 #	endif
