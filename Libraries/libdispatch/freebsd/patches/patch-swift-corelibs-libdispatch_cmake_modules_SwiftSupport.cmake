--- swift-corelibs-libdispatch/cmake/modules/SwiftSupport.cmake.orig	2023-06-15 00:55:45 UTC
+++ swift-corelibs-libdispatch/cmake/modules/SwiftSupport.cmake
@@ -29,6 +29,8 @@ function(get_swift_host_arch result_var_name)
     set("${result_var_name}" "armv7" PARENT_SCOPE)
   elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "AMD64")
     set("${result_var_name}" "x86_64" PARENT_SCOPE)
+  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "amd64")
+    set("${result_var_name}" "x86_64" PARENT_SCOPE)
   elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "IA64")
     set("${result_var_name}" "itanium" PARENT_SCOPE)
   elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "x86")
