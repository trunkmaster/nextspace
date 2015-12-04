include(CMakeParseArguments)
include(CheckSymbolExists)

function (DSCheckDecls)
  cmake_parse_arguments(args "REQUIRED" "" "INCLUDES" ${ARGN})

  foreach (decl IN LISTS args_UNPARSED_ARGUMENTS)
    string (REGEX REPLACE "[^a-zA-Z0-9_]" "_" var "${decl}")
    string(TOUPPER "${var}" var)
    set(var "HAVE_DECL_${var}")
    check_symbol_exists("${decl}" "${args_INCLUDES}" "${var}")

    if (args_REQUIRED AND NOT ${var})
      unset("${var}" CACHE)
      message(FATAL_ERROR "Could not find symbol ${decl}")
    endif ()
  endforeach ()
endfunction ()