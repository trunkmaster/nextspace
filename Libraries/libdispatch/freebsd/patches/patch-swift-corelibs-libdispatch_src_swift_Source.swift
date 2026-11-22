--- swift-corelibs-libdispatch/src/swift/Source.swift.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/src/swift/Source.swift
@@ -116,7 +116,7 @@ extension DispatchSource {
 	}
 #endif
 
-#if !os(Linux) && !os(Android) && !os(Windows)
+#if HAVE_MACH
 	public struct ProcessEvent : OptionSet, RawRepresentable {
 		public let rawValue: UInt
 		public init(rawValue: UInt) { self.rawValue = rawValue }
@@ -174,7 +174,7 @@ extension DispatchSource {
 	}
 #endif
 
-#if !os(Linux) && !os(Android) && !os(Windows)
+#if HAVE_MACH
 	public class func makeProcessSource(identifier: pid_t, eventMask: ProcessEvent, queue: DispatchQueue? = nil) -> DispatchSourceProcess {
 		let source = dispatch_source_create(_swift_dispatch_source_type_PROC(), UInt(identifier), eventMask.rawValue, queue?.__wrapped)
 		return DispatchSource(source: source) as DispatchSourceProcess
@@ -224,7 +224,7 @@ extension DispatchSource {
 		return DispatchSource(source: source) as DispatchSourceUserDataReplace
 	}
 
-#if !os(Linux) && !os(Android) && !os(Windows)
+#if HAVE_MACH
 	public class func makeFileSystemObjectSource(fileDescriptor: Int32, eventMask: FileSystemEvent, queue: DispatchQueue? = nil) -> DispatchSourceFileSystemObject {
 		let source = dispatch_source_create(_swift_dispatch_source_type_VNODE(), UInt(fileDescriptor), eventMask.rawValue, queue?.__wrapped)
 		return DispatchSource(source: source) as DispatchSourceFileSystemObject
@@ -290,7 +290,7 @@ extension DispatchSourceMemoryPressure {
 }
 #endif
 
-#if !os(Linux) && !os(Android) && !os(Windows)
+#if HAVE_MACH
 extension DispatchSourceProcess {
 	public var handle: pid_t {
 		return pid_t(dispatch_source_get_handle(self as! DispatchSource))
@@ -646,7 +646,7 @@ extension DispatchSourceTimer {
 	}
 }
 
-#if !os(Linux) && !os(Android) && !os(Windows)
+#if HAVE_MACH
 extension DispatchSourceFileSystemObject {
 	public var handle: Int32 {
 		return Int32(dispatch_source_get_handle((self as! DispatchSource).__wrapped))
