set (sources
  apply.c
  benchmark.c
  init.c
  object.c
  once.c
  queue.c
  semaphore.c
  source.c
  time.c
)

if (CBLOCKS_COMPILER_SUPPORT_FOUND)
  list (APPEND sources
    data.c
    data_additions.c
    io.c
    io_additions.c
    transform.c
  )
endif ()

option (COMPILE_C_AS_CXX "Compile .c sources as C++" FALSE)
if (COMPILE_C_AS_CXX)
  set_property(SOURCE ${sources} PROPERTY LANGUAGE CXX)
  set_property(SOURCE ${sources} APPEND PROPERTY 
    COMPILE_DEFINITIONS "__STDC_LIMIT_MACROS;__STDC_FORMAT_MACROS"
  )
  # Suppress Clang warning
  DSAddCompilerFlags(SOURCE ${sources} FLAGS "-x c++")
endif ()

if (USE_MIG)
  list(APPEND sources
    protocol.defs
    provider.d
  )
endif ()

include_directories (
  "${dispatch_SOURCE_DIR}"
  "${dispatch_BINARY_DIR}"
  "${dispatch_SOURCE_DIR}/private"
  "${dispatch_SOURCE_DIR}/os"
  "${KQUEUE_INCLUDE_DIRS}"
  "${PTHREAD_WORKQUEUE_INCLUDE_DIRS}"
  "${CBLOCKS_INCLUDE_DIRS}"
)


set (cflags
  -Wall
  -Wextra
  -Wno-unused-parameter
  ${VISIBILITY_FLAGS}
  ${OMIT_LEAF_FP_FLAGS}
  ${CBLOCKS_COMPILE_FLAGS}
)

if (CMAKE_C_COMPILER_ID MATCHES "GNU")
  list(APPEND cflags -Wno-unknown-pragmas -Wno-missing-field-initializers)
endif ()

if (HAVE_DARWIN_LD)
  list (APPEND linker_flags 
    "-Wl,-compatibility_version,1"
    "-Wl,-current_version,${dispatch_VERSION}"
    "-Wl,-dead_strip"
  )
endif ()

if (USE_OBJC)
  list (APPEND sources object.m)
  DSAddCompilerFlags(SOURCE object.m FLAGS "-fobjc-gc")
  
  list (APPEND linker_flags
    -Wl,-upward-lobjc
    -Wl,-upward-lauto
    -Wl,-order_file,${dispatch_SOURCE_DIR}/xcodeconfig/libdispatch.order
    -Wl,-alias_list,${dispatch_SOURCE_DIR}/xcodeconfig/libdispatch.aliases
    -Wl,-unexported_symbols_list,${dispatch_SOURCE_DIR}/xcodeconfig/libdispatch.unexport
  )
endif ()


# if (USE_MIG)
#   set (BUILD_SOURCES
#     protocolUser.c
#     protocol.h
#     protocolServer.c
#     protocolServer.h
#   )
#
#   %User.c %.h %Server.c %Server.h: ${abs_srcdir}/%.defs
#     ${MIG} -user $*User.c -header $*.h
#         -server $*Server.c -sheader $*Server.h $<
# endif ()

add_library(libdispatch_static STATIC ${sources})
add_library(libdispatch_shared SHARED ${sources})

DSAddCompilerFlags(TARGET libdispatch_static libdispatch_shared
  FLAGS ${cflags})

DSTargetAddLinkerFlags(TARGET libdispatch_static libdispatch_shared
  FLAGS ${linker_flags})

foreach (target libdispatch_shared libdispatch_static)
  target_link_libraries(${target}
    ${CMAKE_THREAD_LIBS_INIT}
    ${PTHREAD_WORKQUEUE_LIBRARIES}
    ${KQUEUE_LIBRARIES}
    ${CBLOCKS_LIBRARIES}
    ${CLOCK_GETTIME_LIBRARIES}
  )
endforeach ()

set_property(TARGET libdispatch_static libdispatch_shared PROPERTY
  OUTPUT_NAME dispatch)

set_target_properties(libdispatch_shared PROPERTIES 
  SOVERSION 0
  VERSION ${dispatch_VERSION}
)

install(
  TARGETS libdispatch_shared libdispatch_static
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
)
