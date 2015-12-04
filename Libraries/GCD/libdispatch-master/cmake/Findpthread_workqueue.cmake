include (FindPackageHandleStandardArgs)
include (CheckFunctionExists)

find_path(PTHREAD_WORKQUEUE_INCLUDE_DIRS pthread_workqueue.h)

check_function_exists(PTHREAD_WORKQUEUE_IN_LIBC pthread_workqueue_create_np)

if (PTHREAD_WORKQUEUE_IN_LIBC)
  set (PTHREAD_WORKQUEUE_LIBRARIES " ")
else ()
  find_library(PTHREAD_WORKQUEUE_LIBRARIES "pthread_workqueue")
endif ()

find_package_handle_standard_args(pthread_workqueue DEFAULT_MSG
  PTHREAD_WORKQUEUE_LIBRARIES
  PTHREAD_WORKQUEUE_INCLUDE_DIRS
)