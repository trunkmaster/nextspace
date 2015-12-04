
if (NOT DISPATCH_ENABLE_TEST_SUITE)
  return ()
endif ()

add_library(bsdtests OBJECT
  bsdtests.c
  bsdtests.h
  dispatch_test.c
  dispatch_test.h
  shims.h
  shims/asprintf.c
  shims/asprintf.h
  shims/arc4random.c
  shims/arc4random.h
  shims/fgetln.c
  shims/fgetln.h
)

set (dispatch_tests
  dispatch_apply
  dispatch_api
  dispatch_c99
  dispatch_debug
  dispatch_queue_finalizer
  dispatch_group
  dispatch_overcommit
  dispatch_pingpong
  dispatch_plusplus
  dispatch_priority
  dispatch_priority2
  dispatch_concur
  dispatch_context_for_key
  dispatch_proc
  dispatch_read
  dispatch_read2
  dispatch_after
  dispatch_timer
  dispatch_timer_short
  dispatch_timer_timeout
  dispatch_sema
  dispatch_suspend_timer
  dispatch_timer_bit31
  dispatch_timer_bit63
  dispatch_timer_set_time
  dispatch_starfish
  dispatch_cascade
  dispatch_drift
  dispatch_readsync
  dispatch_data
  dispatch_io
  dispatch_io_net
  dispatch_vm
  dispatch_vnode
  dispatch_select
)

if (HAVE_MACH)
  list (APPEND dispatch_tests dispatch_deadname)
endif ()

set (dispatch_tests_CFLAGS   
  -Wall
  -Wextra
  -Wno-unused-parameter
  ${CBLOCKS_COMPILE_FLAGS}
)

# Sometimes we need to link additional libraries for maths functions
DSSearchLibs(sin LIBRARIES m REQUIRED)
set (MATH_LIBRARIES "${SIN_LIBRARIES}")

set (dispatch_tests_LIBRARIES
  libdispatch_shared
  ${MATH_LIBRARIES}
)

set (dispatch_priority2_SOURCES dispatch_priority.c)
set (dispatch_priority2_DEFINITIONS USE_SET_TARGET_QUEUE=1)

include_directories(
  ${dispatch_BINARY_DIR}
  ${dispatch_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_CURRENT_BINARY_DIR}
)

# Give the test suite access to dispatch's private headers
execute_process(COMMAND ${CMAKE_COMMAND} -E 
  create_symlink "${dispatch_SOURCE_DIR}/private" "dispatch"
  WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
)

include_directories(
  "${KQUEUE_INCLUDE_DIRS}"
  "${PTHREAD_WORKQUEUE_INCLUDE_DIRS}"
  "${CBLOCKS_INCLUDE_DIRS}"
)

if (HAVE_COREFOUNDATION)
  include_directories(${COREFOUNDATION_INCLUDE_DIRS})

  list (APPEND dispatch_tests
    dispatch_cf_main
    dispatch_transform
    dispatch_sync_on_main
    cffd
  )

  find_library(SECURITY_LIBRARIES Security)

  set (dispatch_cf_main_LIBRARIES ${COREFOUNDATION_LIBRARIES})
  set (dispatch_transform_LIBRARIES ${COREFOUNDATION_LIBRARIES} ${SECURITY_LIBRARIES})
  set (dispatch_sync_on_main_LIBRARIES ${COREFOUNDATION_LIBRARIES})
  set (cffd_LIBRARIES ${COREFOUNDATION_LIBRARIES})
endif ()

if (HAVE_FOUNDATION)
  include_directories(${FOUNDATION_INCLUDE_DIRS})

# XXX
# set (AM_OBJCFLAGS -Wall ${CBLOCKS_FLAGS} -fobjc-gc)

  list (APPEND dispatch_tests
    dispatch_sync_gc
    dispatch_apply_gc
    nsoperation
    bench
  )

  set (dispatch_sync_gc_LIBRARIES ${FOUNDATION_LIBRARIES})
  set (dispatch_apply_gc_LIBRARIES ${FOUNDATION_LIBRARIES})
  set (nsoperation_LIBRARIES ${FOUNDATION_LIBRARIES})
  set (bench_SOURCES func.c)
  set (bench_LIBRARIES ${FOUNDATION_LIBRARIES})
endif ()



# Add the tests

foreach (test IN LISTS dispatch_tests)
  set (test_source "${test}")
  if (DEFINED ${test}_SOURCES)
    set (test_source "${${test}_SOURCES}")
  endif ()

  add_executable("${test}" "${test_source}" "$<TARGET_OBJECTS:bsdtests>")

  if (DEFINED ${test}_DEFINITIONS)
    set_property(TARGET ${test} APPEND PROPERTY
      COMPILE_DEFINITIONS ${${test}_DEFINITIONS})
  endif ()

  if (DEFINED ${test}_LIBRARIES)
    target_link_libraries("${test}"
      COMPILE_DEFINITIONS ${${test}_LIBRARIES})
  endif ()

  DSAddCompilerFlags(TARGET "${test}" FLAGS
    ${dispatch_tests_CFLAGS}
  )

  target_link_libraries("${test}" ${dispatch_tests_LIBRARIES})


  get_property(test_exe_path TARGET ${test} PROPERTY LOCATION)

  add_test(NAME "${test}" COMMAND bsdtestharness ${test_exe_path})
endforeach ()


add_executable(bsdtestharness 
  bsdtestharness.c
  "$<TARGET_OBJECTS:bsdtests>"
)
add_executable(bsdtestsummarize
  bsdtestsummarize.c
  "$<TARGET_OBJECTS:bsdtests>"
)

target_link_libraries(bsdtestharness ${dispatch_tests_LIBRARIES})
target_link_libraries(bsdtestsummarize ${dispatch_tests_LIBRARIES})

DSAddCompilerFlags(TARGET bsdtestharness bsdtestsummarize FLAGS
  ${dispatch_tests_CFLAGS}
)

add_custom_target(check
  COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure 
  DEPENDS bsdtestharness ${dispatch_tests}
  VERBATIM
)
