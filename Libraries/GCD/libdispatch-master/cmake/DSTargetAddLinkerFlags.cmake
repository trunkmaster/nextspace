include(CMakeParseArguments)

function (DSTargetAddLinkerFlags)
  cmake_parse_arguments(args "" "" "TARGET;FLAGS" ${ARGN})

  foreach (target IN LISTS args_TARGET)
    # This, bizarrely enough, seems to be the way to add linker flags in CMake.
    target_link_libraries("${target}" ${args_FLAGS})
  endforeach ()
endfunction ()