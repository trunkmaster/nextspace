include (CMakeParseArguments)

# Annoyingly compiler flags in CMake are a space-separated string,
# not a list. This function allows for more consistent behaviour.
function (DSAddCompilerFlags)
  cmake_parse_arguments(args "" "" "FLAGS" ${ARGN})

  set (space_separated_flags "")
  foreach (flag IN LISTS args_FLAGS)
    set (space_separated_flags "${space_separated_flags} ${flag}")
  endforeach ()

  set_property(${args_UNPARSED_ARGUMENTS} APPEND_STRING
    PROPERTY COMPILE_FLAGS "${space_separated_flags}")
endfunction ()