include(CMakeParseArguments)
include(CheckFunctionExists)

function (DSCheckFuncs)
  cmake_parse_arguments(args "REQUIRED" "" "" ${ARGN})

  foreach (function IN LISTS args_UNPARSED_ARGUMENTS)
    string (REGEX REPLACE "[^a-zA-Z0-9_]" "_" var "${function}")
    string(TOUPPER "${var}" var)
    set(var "HAVE_${var}")
    check_function_exists("${function}" "${var}")

    if (args_REQUIRED AND NOT ${var})
      unset("${var}" CACHE)
      message(FATAL_ERROR "Could not find function ${function}")
    endif ()
  endforeach ()
endfunction ()