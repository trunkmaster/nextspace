
function (DSSanitiseBuildType)
  set (build_cache_string "Choose the type of build; options are: Debug Release RelWithDebInfo MinSizeRel.")
  if (NOT CMAKE_BUILD_TYPE)
    set (CMAKE_BUILD_TYPE "Debug" CACHE STRING "${build_cache_string}" FORCE)
  else ()
    set (CMAKE_BUILD_TYPE "${CMAKE_BUILD_TYPE}" CACHE STRING "${build_cache_string}" FORCE)
  endif ()
endfunction ()
