include (CheckLibraryExists)
include (CheckFunctionExists)
include (CMakeParseArguments)

function (DSSearchLibs function)
  cmake_parse_arguments(args "REQUIRED" "" "LIBRARIES" ${ARGN})
  
  set (have_function_variable_name "HAVE_${function}")
  string(TOUPPER "${have_function_variable_name}" have_function_variable_name)

  set (function_libraries_variable_name "${function}_LIBRARIES")
  string(TOUPPER "${function_libraries_variable_name}"
    function_libraries_variable_name)

  if (DEFINED ${have_function_variable_name})
    return ()
  endif ()

  # First, check without linking anything in particular.
  check_function_exists("${function}" "${have_function_variable_name}")
  if (${have_function_variable_name})
    # No extra libs needed
    set (${function_libraries_variable_name} "" CACHE INTERNAL "Libraries for ${function}")
    return ()
  else ()
    unset (${have_function_variable_name} CACHE)
  endif ()

  foreach (lib IN LISTS args_LIBRARIES)
    check_library_exists("${lib}" "${function}" "" "${have_function_variable_name}")
    if (${have_function_variable_name})
      set (${function_libraries_variable_name} "${lib}" CACHE INTERNAL "Libraries for ${function}")
      return ()
    else ()
      unset (${have_function_variable_name} CACHE)
    endif ()
  endforeach ()
  
  if (args_REQUIRED)
    message(FATAL_ERROR "Could not find ${function} in any of: " ${args_LIBRARIES})
  endif ()

  set (${function_libraries_variable_name} "" CACHE INTERNAL "Libraries for ${function}")
  set (${have_function_variable_name} NO CACHE INTERNAL "Have function ${function}")
endfunction ()
