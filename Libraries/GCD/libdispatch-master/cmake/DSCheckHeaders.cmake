include(CMakeParseArguments)
include(CheckIncludeFile)

function (DSCheckHeaders)
  cmake_parse_arguments(args "REQUIRED" "" "" ${ARGN})

  foreach (header IN LISTS args_UNPARSED_ARGUMENTS)
    string (REGEX REPLACE "[^a-zA-Z0-9_]" "_" var "${header}")
    string(TOUPPER "${var}" var)
    set(var "HAVE_${var}")
    check_include_file("${header}" "${var}")

    if (args_REQUIRED AND NOT ${var})
      unset("${var}" CACHE)
      message(FATAL_ERROR "Could not find header ${header}")
    endif ()
  endforeach ()
endfunction ()