--- swift-corelibs-libdispatch/src/init.c.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/init.c
@@ -1048,7 +1048,7 @@ _dispatch_bug_kevent_vanished(dispatch_unote_t du)
 	_dispatch_log_fault("LIBDISPATCH_STRICT: _dispatch_bug_kevent_vanished",
 			"BUG in libdispatch client: %s, monitored resource vanished before "
 			"the source cancel handler was invoked "
-			"{ %p[%s], ident: %" PRIdPTR " / 0x%" PRIxPTR ", handler: %p }",
+			"{ %p[%s], ident: %" PRIu32 " / 0x%" PRIx32 ", handler: %p }",
 			dux_type(du._du)->dst_kind, dou._dq,
 			dou._dq->dq_label ? dou._dq->dq_label : "<unknown>",
 			du._du->du_ident, du._du->du_ident, func);
