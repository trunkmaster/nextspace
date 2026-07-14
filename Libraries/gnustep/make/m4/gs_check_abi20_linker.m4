# SYNOPSIS
#
#   GS_CHECK_ABI20_LINKER([run-if-true],[run-if-false])
#
# DESCRIPTION
#
#   This macro checks whether we are using a linker that has known problems with the gnustep-2.0 ABI.
#   If so, we currently just print a warning because we don't have a 100% accurate way of checking yet.
#
AC_DEFUN([GS_CHECK_ABI20_LINKER], [
  AC_MSG_CHECKING([which linker is being used])

  echo 'int main() { return 0; }' > conftest.c

  # Try compiling with verbose output to capture linker information.
  $CC $CFLAGS $LDFLAGS -o conftest conftest.c -Wl,--verbose > compile.log 2>&1

  # Determine which linker is being used based on the log.
  linker="unknown"  # Default to unknown.
  if grep -q "GNU ld" compile.log; then
    linker="GNU ld"
  # GNU gold does not print a header line, so we just check for "gold".
  elif grep -q "gold" compile.log; then
    linker="GNU gold"
  # LLD does not print a header line, so we just check for "lld".
  elif grep -q "lld" compile.log; then
    linker="lld"
  fi

  AC_MSG_RESULT([$linker])

  # Clean up the test artifacts.
  rm -f conftest.c conftest

  # Based on the identified linker, we may want to display a warning or take other actions.
  if test "x$linker" = "xGNU ld"; then
    AC_MSG_WARN([The detected linker (GNU ld) might not produce working Objective-C binaries using the gnustep-2.0 ABI. Consider using GNU gold or LLD.])
  elif test "x$linker" = "xunknown" && test -n "$explicit_linker_flag"; then
    AC_MSG_WARN([Unable to confirm if the explicitly specified linker '$explicit_linker_flag' is compatible with the gnustep-2.0 ABI.])
  fi
])
