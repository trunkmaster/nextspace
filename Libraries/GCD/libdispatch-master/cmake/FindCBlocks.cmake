# Components: private_headers, compiler_support

include (FindPackageHandleStandardArgs)
include (CheckFunctionExists)

find_path(CBLOCKS_PUBLIC_INCLUDE_DIR Block.h
  DOC "Path to Block.h"
)

if (CBLOCKS_PUBLIC_INCLUDE_DIR)
  list (APPEND CBLOCKS_INCLUDE_DIRS ${CBLOCKS_PUBLIC_INCLUDE_DIR})
endif ()

find_path(CBLOCKS_PRIVATE_INCLUDE_DIR Block_private.h
  DOC "Path to Block_private.h"
)
if (CBLOCKS_PRIVATE_INCLUDE_DIR)
  list (APPEND CBLOCKS_INCLUDE_DIRS ${CBLOCKS_PRIVATE_INCLUDE_DIR})
  set (CBlocks_private_headers_FOUND TRUE)  # for FPHSA
  set (CBLOCKS_PRIVATE_HEADERS_FOUND TRUE)  # for everyone else
endif ()

check_function_exists(CBLOCKS_RUNTIME_IN_LIBC _Block_copy)

if (CBLOCKS_RUNTIME_IN_LIBC)
  set (CBLOCKS_LIBRARIES " ")
else ()
  find_library(CBLOCKS_LIBRARIES "BlocksRuntime")
endif ()

check_c_compiler_flag("-fblocks" CBLOCKS_COMPILER_SUPPORT_FOUND)
if (CBLOCKS_COMPILER_SUPPORT_FOUND)
  set (CBLOCKS_COMPILE_FLAGS "-fblocks")
  set (CBlocks_compiler_support_FOUND TRUE)  # for FPHSA
endif ()

find_package_handle_standard_args(CBlocks
  REQUIRED_VARS CBLOCKS_LIBRARIES CBLOCKS_PUBLIC_INCLUDE_DIR
  HANDLE_COMPONENTS
)

