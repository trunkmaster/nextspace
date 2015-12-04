cmake_minimum_required(VERSION 2.8.8)

project (dispatch)
set (dispatch_VERSION "1.2")

list (APPEND CMAKE_MODULE_PATH "${dispatch_SOURCE_DIR}/cmake")

include (CheckCCompilerFlag)
include (CheckCSourceCompiles)
include (CMakePushCheckState)
include (CTest)

include (DSAddCompilerFlags)
include (DSCheckDecls)
include (DSCheckFuncs)
include (DSCheckHeaders)
include (DSSanitiseBuildType)
include (DSSearchLibs)
include (DSTargetAddLinkerFlags)

DSSanitiseBuildType()
message(STATUS "Build type is: ${CMAKE_BUILD_TYPE}")

if (CMAKE_SYSTEM_NAME MATCHES "Linux")
  add_definitions(-D_GNU_SOURCE)
endif ()

set (DISPATCH_INCLUDE_DIR "include" CACHE STRING
  "Appended to CMAKE_INSTALL_PREFIX to determine where the headers are installed.")

################################################################################
# Darwin-specific stuff
# 
# On Mac OS X, some required header files come from other source packages;
# allow specifying where those are.
#
set (APPLE_LIBC_SOURCE "" CACHE PATH "Specify path to Apple Libc source")
if (APPLE_LIBC_SOURCE)
  include_directories(SYSTEM "${APPLE_LIBC_SOURCE}/pthreads")
endif ()

set (APPLE_LIBCLOSURE_SOURCE "" CACHE PATH "Specify path to Apple libclosure source")
if (APPLE_LIBCLOSURE_SOURCE)
  include_directories(SYSTEM "${APPLE_LIBCLOSURE_SOURCE_PATH}")
endif ()

set (APPLE_XNU_SOURCE "" CACHE PATH "Specify path to Apple XNU source")
if (APPLE_XNU_SOURCE)
  set (apple_xnu_source_libkern_path "${APPLE_XNU_SOURCE}/libkern")
  set (apple_xnu_source_bsd_path "${APPLE_XNU_SOURCE}/bsd")
  set (apple_xnu_source_osfmk_path "${APPLE_XNU_SOURCE}/osfmk")
  DSAddCompileFlags(DIRECTORY FLAGS
    "-idirafter" "${apple_xnu_source_libkern_path}"
    "-isystem" "${apple_xnu_source_bsd_path}"
  )
endif ()

set (APPLE_OBJC4_SOURCE "" CACHE PATH "Specify path to Apple objc4 source")
if (APPLE_OBJC4_SOURCE)
  set (apple_objc4_source_runtime_path "${APPLE_OBJC4_SOURCE}/runtime")
endif ()

set (APPLE_LIBAUTO_SOURCE "" CACHE PATH "Specify path to Apple libauto source")
if (APPLE_LIBAUTO_SOURCE)
  include_directories(SYSTEM "${APPLE_LIBAUTO_SOURCE}")
endif ()

if (IS_DIRECTORY /System/Library/Frameworks/System.framework/PrivateHeaders)
  include_directories(SYSTEM /System/Library/Frameworks/System.framework/PrivateHeaders)
endif ()

#
# On Mac OS X, libdispatch_init is automatically invoked during libSystem
# process initialization.  On other systems, it is tagged as a library
# constructor to be run by automatically by the runtime linker.
#

if (NOT DEFINED USE_LIBDISPATCH_INIT_CONSTRUCTOR)
  if (EXISTS /usr/lib/system/libdispatch.dylib)
    set (initial_value NO)
  else ()
    set (initial_value YES)
  endif ()

  option (USE_LIBDISPATCH_INIT_CONSTRUCTOR
    "Use libdispatch_init as a constructor"
    ${initial_value}
  )
endif ()

#
# On Mac OS X libdispatch can use the non-portable direct pthread TSD functions
#
option(USE_APPLE_TSD_OPTIMIZATIONS "Use non-portable pthread TSD optimizations for Mac OS X." OFF)

find_program(MIG_EXECUTABLE mig)
find_program(LEAKS_EXECUTABLE leaks DOC "Path to Apple leaks program")
if (LEAKS_EXECUTABLE)
  set (HAVE_LEAKS YES)
endif ()

################################################################################

check_c_source_compiles("int main() { int i, x = 0; i = __sync_add_and_fetch(&x,1); return x; }" 
  HAVE_ATOMIC_BUILTINS)
if (NOT HAVE_ATOMIC_BUILTINS)
  message(FATAL_ERROR "GCC atomic builtins are required")
endif ()

#
# Find libraries we will need
#

DSSearchLibs(clock_gettime LIBRARIES rt)

find_package(Threads REQUIRED)
find_package(kqueue REQUIRED)

find_package(CBlocks REQUIRED COMPONENTS private_headers
  OPTIONAL_COMPONENTS compiler_support)

if (NOT CBLOCKS_COMPILER_SUPPORT_FOUND)
  message(WARNING "Blocks compiler support was not found; dispatch i/o "
                  "will not be built.")
endif ()

DSCheckHeaders(
  TargetConditionals.h
  pthread_np.h
  malloc/malloc.h
  libkern/OSCrossEndian.h
  libkern/OSAtomic.h
  libkern/OSByteOrder.h
)


# hack for pthread_machdep.h's #include <System/machine/cpu_capabilities.h>
cmake_push_check_state ()
  if (EXISTS "${apple_xnu_source_osfmk_path}")
      list(APPEND CMAKE_REQUIRED_INCLUDES "${CMAKE_CURRENT_BINARY_DIR}")
      execute_process(
        COMMAND ${CMAKE_COMMAND} -E 
            create_symlink "${apple_xnu_source_osfmk_path}" System
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
      )
  endif ()
  DSCheckHeaders(pthread_machdep.h)
cmake_pop_check_state ()

# hack for xnu/bsd/sys/event.h EVFILT_SOCK declaration
if (EXISTS "${apple_xnu_source_bsd_path}")
  add_definitions(-DPRIVATE=1)
endif ()

#
# Check for CoreFoundation, Foundation and objc
#
find_package(CoreFoundation)
set (HAVE_COREFOUNDATION ${COREFOUNDATION_FOUND})

find_package(Foundation)
set (HAVE_FOUNDATION "${FOUNDATION_FOUND}")
  
# hack for objc4/runtime/objc-internal.h
cmake_push_check_state ()
  if (EXISTS "${apple_objc4_source_runtime_path}")
    list (APPEND CMAKE_REQUIRED_INCLUDES "${CMAKE_CURRENT_BINARY_DIR}")
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E
          create_symlink "${apple_objc4_source_runtime_path}" objc
      WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    )
  endif ()
cmake_pop_check_state ()

cmake_push_check_state ()
  list (APPEND CMAKE_REQUIRED_INCLUDES "${CMAKE_CURRENT_BINARY_DIR}")
  DSCheckHeaders(objc/objc-internal.h)
  set (USE_OBJC "${HAVE_OBJC_OBJC_INTERNAL_H}")
cmake_pop_check_state()


#
# We use the availability of mach.h to decide whether to compile in all sorts
# of Machisms, including using Mach ports as event sources, etc.
#
DSCheckHeaders(mach/mach.h)
if (HAVE_MACH_MACH_H)
  set (HAVE_MACH 1)
  set (USE_MIG 1)
  set (__DARWIN_NON_CANCELABLE 1)
endif ()

#
# We use the availability of pthread_workqueue.h to decide whether to compile
# in support for pthread work queues.
#
find_package(pthread_workqueue)
set (HAVE_PTHREAD_WORKQUEUES "${PTHREAD_WORKQUEUE_FOUND}")
DSSearchLibs(pthread_workqueue_setdispatch_np LIBRARIES "${PTHREAD_WORKQUEUE_LIBRARIES}")


#
# Find functions and declarations we care about.
#
DSCheckDecls(CLOCK_UPTIME CLOCK_MONOTONIC   INCLUDES time.h)
DSCheckDecls(NOTE_NONE NOTE_REAP NOTE_SIGNAL NOTE_REVOKE  INCLUDES sys/event.h)
DSCheckDecls(TAILQ_FOREACH_SAFE  INCLUDES sys/queue.h) 
DSCheckDecls(FD_COPY  INCLUDES sys/select.h) 
DSCheckDecls(SIGEMT   INCLUDES signal.h) 
DSCheckDecls(VQ_UPDATE VQ_VERYLOWDISK   INCLUDES sys/mount.h)

cmake_push_check_state ()
  set (CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
  DSCheckDecls(program_invocation_short_name    INCLUDES errno.h)
cmake_pop_check_state ()

DSCheckFuncs(pthread_key_init_np pthread_main_np)
DSCheckFuncs(mach_absolute_time malloc_create_zone)
DSCheckFuncs(sysctlbyname sysconf getprogname)
DSCheckFuncs(strlcpy asprintf)

DSCheckDecls(POSIX_SPAWN_SETEXEC POSIX_SPAWN_START_SUSPENDED
  INCLUDES sys/spawn.h
)

#
# We support both Mach semaphores and POSIX semaphores; if the former are
# available, prefer them.

cmake_push_check_state ()
  set (CMAKE_REQUIRED_LIBRARIES "${CMAKE_THREAD_LIBS_INIT}")
  DSSearchLibs(sem_init LIBRARIES "rt")
cmake_pop_check_state ()

if (HAVE_MACH)
  set (USE_MACH_SEM 1)
elseif (HAVE_SEM_INIT)
  set (USE_POSIX_SEM 1)
else ()
  message(FATAL_ERROR "no supported semaphore type")
endif ()

DSCheckHeaders(sys/cdefs.h unistd.h)

if (HAVE_UNISTD_H AND CBLOCKS_COMPILER_SUPPORT_FOUND)
    cmake_push_check_state()
        set(CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
        set(CMAKE_REQUIRED_FLAGS -fblocks)
        check_c_source_compiles("#include <unistd.h>\nint main(){}"
            HAS_WORKING_UNISTD_H)
    cmake_pop_check_state()
    if (NOT HAS_WORKING_UNISTD_H)
        set (HAS_PROBLEMATIC_UNISTD_H 1)
    endif ()
endif ()

check_c_compiler_flag("-fvisibility=hidden" SUPPORTS_FVISIBILITY_HIDDEN)
if (SUPPORTS_FVISIBILITY_HIDDEN)
  set (VISIBILITY_FLAGS "-fvisibility=hidden")
endif ()


check_c_compiler_flag("-momit-leaf-frame-pointer" SUPPORTS_MOMIT_LEAF_FRAME_POINTER)
if (SUPPORTS_MOMIT_LEAF_FRAME_POINTER)
  set (OMIT_LEAF_FP_FLAGS "-momit-leaf-frame-pointer")
endif ()

# Check for darwin linker
cmake_push_check_state()
set (CMAKE_REQUIRED_FLAGS "-dynamiclib -Wl,-compatibility_version,1.2.3 -Wl,-current_version,4.5.6 -Wl,-dead_strip")
check_c_source_compiles("extern int foo; int foo; int main() { foo = 0; }" HAVE_DARWIN_LD)
cmake_pop_check_state()

#
# Temporary: some versions of clang do not mark __builtin_trap() as
# __attribute__((__noreturn__)).  Detect and add if required.
#
check_c_source_compiles(
  "void __attribute__((__noreturn__)) temp(void) { __builtin_trap(); } int main() {}"
  HAVE_NORETURN_BUILTIN_TRAP
)

configure_file("config/config.h.cmake.in"
  "${dispatch_BINARY_DIR}/config/config.h"
  @ONLY
)

################################################################################

include_directories(SYSTEM fixincludes)

add_subdirectory(src)
add_subdirectory(testing)

# Install man pages
add_subdirectory(man)

# Install public headers
add_subdirectory(dispatch) 
add_subdirectory(os)
