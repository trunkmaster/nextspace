include (FindPackageHandleStandardArgs)

find_path(FOUNDATION_INCLUDE_DIRS Foundation/Foundation.h)
find_library(FOUNDATION_LIBRARIES Foundation)

find_package_handle_standard_args(Foundation DEFAULT_MSG
  FOUNDATION_LIBRARIES
  FOUNDATION_INCLUDE_DIRS
)
