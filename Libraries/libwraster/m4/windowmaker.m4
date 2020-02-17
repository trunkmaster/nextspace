# windowmaker.m4 - General macros for Window Maker autoconf
#
# Copyright (c) 2004 Dan Pascu
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


dnl Tell m4 to not allow stuff starting with "WM_" in the generated file
dnl because this is likely a problem of a macro that was not expanded as
dnl expected (with an exception for an already used variable name)
m4_pattern_forbid([^_?WM_])
m4_pattern_allow([^WM_OSDEP(_[A-Z]*)?$])


# WM_CHECK_XFT_VERSION(MIN_VERSION, [ACTION-IF-FOUND [,ACTION-IF-NOT-FOUND]])
#
# $XFTFLAGS should be defined before calling this macro,
# else it will not be able to find Xft.h
#
AC_DEFUN([WM_CHECK_XFT_VERSION],
[
CPPFLAGS_old="$CPPFLAGS"
CPPFLAGS="$CPPFLAGS $XFTFLAGS $inc_search_path"
xft_major_version=`echo $1 | sed 's/\([[0-9]]*\).\([[0-9]]*\).\([[0-9]]*\)/\1/'`
xft_minor_version=`echo $1 | sed 's/\([[0-9]]*\).\([[0-9]]*\).\([[0-9]]*\)/\2/'`
xft_micro_version=`echo $1 | sed 's/\([[0-9]]*\).\([[0-9]]*\).\([[0-9]]*\)/\3/'`
AC_MSG_CHECKING([whether libXft is at least version $1])
AC_CACHE_VAL(ac_cv_lib_xft_version_ok,
[AC_TRY_LINK(
[/* Test version of libXft we have */
#include <X11/Xlib.h>
#include <X11/Xft/Xft.h>

#if !defined(XFT_VERSION) || XFT_VERSION < $xft_major_version*10000 + $xft_minor_version*100 + $xft_micro_version
#error libXft on this system is too old. Consider upgrading to at least $1
#endif
], [],
eval "ac_cv_lib_xft_version_ok=yes",
eval "ac_cv_lib_xft_version_ok=no")])
if eval "test \"`echo '$ac_cv_lib_xft_version_ok'`\" = yes"; then
  AC_MSG_RESULT(yes)
  ifelse([$2], , :, [$2])
else
  AC_MSG_RESULT(no)
  ifelse([$3], , , [$3])
fi
CPPFLAGS="$CPPFLAGS_old"
])


# _WM_LIB_CHECK_FUNCTS
# --------------------
# (internal shell functions)
#
# Create 2 shell functions:
#  wm_fn_imgfmt_try_link: try to link against library
#  wm_fn_imgfmt_try_compile: try to compile against header
#
AC_DEFUN_ONCE([_WM_LIB_CHECK_FUNCTS],
[@%:@ wm_fn_lib_try_link FUNCTION LFLAGS
@%:@ ----------------------------------
@%:@ Try linking against library in $LFLAGS using function named $FUNCTION
@%:@ Assumes that LIBS have been saved in 'wm_save_LIBS' by caller
wm_fn_lib_try_link ()
{
  LIBS="$wm_save_LIBS $[]2"
  AC_TRY_LINK_FUNC([$[]1],
    [wm_retval=0],
    [wm_retval=1])
  AS_SET_STATUS([$wm_retval])
}

@%:@ wm_fn_lib_try_compile HEADER GVARDEF FUNC_CALL CFLAGS
@%:@ -----------------------------------------------------
@%:@ Try to compile using header $HEADER and trying to call a function
@%:@ using the $FUNC_CALL expression and using extra $CFLAGS in the
@%:@ compiler's command line; GVARDEF can be used to include one line
@%:@ in the global context of the source.
@%:@ Assumes that CFLAGS have been saved in 'wm_save_CFLAGS' by caller
wm_fn_lib_try_compile ()
{
  CFLAGS="$wm_save_CFLAGS $[]4"
  AC_COMPILE_IFELSE(
    [AC_LANG_PROGRAM([@%:@include <$[]1>

$[]2], [  $[]3;])],
    [wm_retval=0],
    [wm_retval=1])
  AS_SET_STATUS([$wm_retval])
}
])


# WM_APPEND_ONCE
# --------------
#
# Append flags to a variable, but only if not already present
#
# Usage: WM_APPEND_ONCE([libflags], [variable])
#   $1 libflags: the list of flag to append
#   $2 variable: the variable, if unset use LIBS
AC_DEFUN([WM_APPEND_ONCE],
[AS_VAR_PUSHDEF([VAR], [m4_ifnblank([$2], [$2], [LIBS])])dnl
for wm_arg in $1 ; do
  AS_IF([echo " $VAR " | grep " $wm_arg " 2>&1 >/dev/null],
        [@%:@ Flag already present in VAR],
        [VAR="$VAR $wm_arg"])
done
AS_VAR_POPDEF([VAR])dnl
])


# WM_LIB_CHECK
# ------------
#
# Check if a library exists (can be linked to) and check if its header can
# compile (using code in parameter to the macro), then update the appropriate
# stuff accordingly
#
# Usage: WM_LIB_CHECK([name], [lflaglist], [lfunc], [extralibs], [headercheck], [supvar], [libvar], [enable_var], [cond_name])
#   $1 name: name of the feature used in messages and in supvar
#   $2 lflaglist: the list of linker '-l' options to try, stopping on first success
#   $3 lfunc: the name of the function to look for when linking
#   $4 extralibs: optional, additional libraries included in the link check
#   $5 headercheck: the code that checks for the header
#   $6 supvar: if the library was found, append $name to this variable,
#              otherwise append $name to 'unsupported'
#   $7 libvar: if the library was found, append the working $lflag to this variable
#   $8 enable_var: variable to check for user's feature request, if empty we use "lowercase(enable_$1)"
#   $9 cond_name: name of the AC_DEFINE and the AM_CONDITIONAL
#                 if empty, use "uppercase(USE_$1)", if equals "-" same but do not create AM_CONDITIONAL
AC_DEFUN([WM_LIB_CHECK],
[AC_REQUIRE([_WM_LIB_CHECK_FUNCTS])
m4_pushdef([ENABLEVAR], [m4_ifnblank([$8], [$8], enable_[]m4_tolower($1))])dnl
m4_pushdef([CACHEVAR], [wm_cv_libchk_[]m4_tolower($1)])dnl
m4_pushdef([USEVAR], [m4_bmatch([$9], [^-?$], [USE_[]m4_toupper($1)], [$9])])dnl
AS_IF([test "x$ENABLEVAR" = "xno"],
    [unsupported="$unsupported $1"],
    [AC_CACHE_CHECK([for $1 support library], CACHEVAR,
        [CACHEVAR=no
         wm_save_LIBS="$LIBS"
         dnl
         dnl We check that the library is available
         m4_bmatch([$2], [ ], dnl Any space in 'lflaglist' means we have a list of flags
            [for wm_arg in $2 ; do
               AS_IF([wm_fn_lib_try_link "$3" "$4 $wm_arg"],
                 [CACHEVAR="$wm_arg" ; break])
             done],
            [AS_IF([wm_fn_lib_try_link "$3" "$4 $2"],
                [CACHEVAR="$2"]) ])
         LIBS="$wm_save_LIBS"
         AS_IF([test "x$ENABLEVAR$CACHEVAR" = "xyesno"],
            [AC_MSG_ERROR([explicit $1 support requested but no library found])])
         dnl
         dnl A library was found, check if header is available and compile
         AS_IF([test "x$CACHEVAR" != "xno"], [$5])
        ])
    AS_IF([test "x$CACHEVAR" = "xno"],
        [unsupported="$unsupported $1"
         ENABLEVAR="no"],
        [$6="$$6 $1"
         WM_APPEND_ONCE([$CACHEVAR], [$7])
         AC_DEFINE(USEVAR, [1],
            [defined when valid $1 library with header was found])])
    ])
m4_bmatch([$9], [^-$], [],
    [AM_CONDITIONAL(USEVAR, [test "x$ENABLEVAR" != "xno"])])dnl
m4_popdef([ENABLEVAR])dnl
m4_popdef([CACHEVAR])dnl
m4_popdef([USEVAR])dnl
])


# WM_FUNC_SECURE_GETENV
# ---------------------
#
# Check if the function 'secure_getenv' is available
# If found, defines HAVE_SECURE_GETENV
AC_DEFUN_ONCE([WM_FUNC_SECURE_GETENV],
[AC_REQUIRE([_WM_LIB_CHECK_FUNCTS])
AC_CACHE_CHECK([for secure_getenv], [wm_cv_func_secure_getenv],
    [wm_cv_func_secure_getenv=no
     wm_save_CFLAGS="$CFLAGS"
     for wm_arg in "% yes" "-D_GNU_SOURCE"; do
         AS_IF([wm_fn_lib_try_compile "stdlib.h" "const char *h;" "h = secure_getenv(\"HOME\")" dnl
                    "`echo "$wm_arg" | sed -e 's, *%.*$,,' ` -Werror=implicit-function-declaration"],
             [wm_cv_func_secure_getenv="`echo "$wm_arg" | sed -e 's,^.*% *,,' `"
              break])
     done
     CFLAGS="$wm_save_CFLAGS"])
AS_IF([test "x$wm_cv_func_secure_getenv" != "xno"],
    [AS_IF([test "x$wm_cv_func_secure_getenv" != "xyes"],
         [WM_APPEND_ONCE([$wm_cv_func_secure_getenv], [CPPFLAGS])])
     AC_DEFINE([HAVE_SECURE_GETENV], [1],
         [defined when GNU's secure_getenv function is available])])
])


# WM_FUNC_OPEN_NOFOLLOW
# ---------------------
#
# Check if the flag 'O_NOFOLLOW' is supported, for the function 'open'
AC_DEFUN_ONCE([WM_FUNC_OPEN_NOFOLLOW],
[AC_CACHE_CHECK([for O_NOFOLLOW], [wm_cv_func_open_nofollow],
    [wm_cv_func_open_nofollow=no
     wm_save_CPPFLAGS="$CPPFLAGS"
     for wm_arg in dnl
"yes"  dnl natively supported, nothing to do
"-D_POSIX_C_SOURCE=200809L"  dnl the flag was officially added in POSIX.1-2008
"-D_XOPEN_SOURCE=700"  dnl for recent glibc
"-D_GNU_SOURCE"  dnl for older glibc
     ; do
         AS_IF([test "x$wm_arg" != "xyes"], [CPPFLAGS="$wm_save_CPPFLAGS $wm_arg"])
         AC_LINK_IFELSE([AC_LANG_PROGRAM([dnl
@%:@include <sys/types.h>
@%:@include <sys/stat.h>
@%:@include <fcntl.h>], [dnl
  int fd;

  fd = open("/dev/null", O_RDONLY | O_NOFOLLOW);
  return fd;])], [found=1], [found=0])
         AS_IF([test $found = 1],
             [wm_cv_func_open_nofollow="$wm_arg"
              break])
     done
     CPPFLAGS="$wm_save_CPPFLAGS"])
AS_CASE([$wm_cv_func_open_nofollow],
    [yes], [],
    [no],  [AC_DEFINE([O_NOFOLLOW], [0],
                [defined by configure if the attribute is not defined on your platform])
            AC_MSG_WARN([flag O_NOFOLLOW is not defined on your platform])],
    [CPPFLAGS="$CPPFLAGS $wm_cv_func_open_nofollow"])
])


# WM_TYPE_SIGNAL
# --------------
#
# Check the return type for the function 'signal'
# Autoconf now claims we can assume the type is 'void' as it is in the C89 standard,
# but as Window Maker is supposed to be lightweight enough for old machines, we
# prefer to keep the check for portability
AC_DEFUN_ONCE([WM_TYPE_SIGNAL],
[AC_CACHE_CHECK([return type of signal handlers], [wm_cv_type_signal],
    [AC_COMPILE_IFELSE(
        [AC_LANG_PROGRAM([#include <sys/types.h>
#include <signal.h>
],
            [return *(signal (0, 0)) (0) == 1;])],
        [wm_cv_type_signal=int],
        [wm_cv_type_signal=void])dnl
    ])
AC_DEFINE_UNQUOTED([RETSIGTYPE], [$wm_cv_type_signal],
    [Define as the return type of signal handlers (`int' or `void')])dnl
])
