# wm_libmath.m4 - Macros to check proper libMath usage for WINGs
#
# Copyright (c) 2013 Christophe Curis
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


# WM_CHECK_LIBM
# -------------
#
# Checks the needed library link flags needed to have math lib
# Sets variable LIBM with the appropriates flags
AC_DEFUN_ONCE([WM_CHECK_LIBM],
[AC_CHECK_HEADER([math.h], [],
                 [AC_MSG_ERROR([header for math library not found])])
AC_CHECK_FUNC(atan,
    [LIBM=],
    [AC_CHECK_LIB(m, [atan],
        [LIBM=-lm],
        [AC_MSG_WARN(Could not find Math library, you may experience problems)
         LIBM=] )] ) dnl
AC_CACHE_CHECK([if M_PI is defined in math.h], [wm_cv_libm_pi],
    [wm_cv_libm_pi="no"
     wm_save_CFLAGS="$CFLAGS"
     for wm_arg in dnl
       "% yes" dnl natively available (Unix98 compliant?)
       "-D_XOPEN_SOURCE=500" ; dnl Explicit request
     do
       AS_IF([wm_fn_lib_try_compile "math.h" "double val;" "val = M_PI" dnl
                  "`echo "$wm_arg" | sed -e 's, *%.*$,,' `"],
           [wm_cv_libm_pi="`echo "$wm_arg" | sed -e 's,^.*% *,,' `" ; break])
     done
     CFLAGS="$wm_save_CFLAGS"])
AS_IF([test "x$wm_cv_libm_pi" = "xno"],
    [AC_DEFINE([WM_PI], [(3.14159265358979323846)],
        [Defines how to access the value of Pi])],
    [AC_DEFINE([WM_PI], [(M_PI)],
        [Defines how to access the value of Pi])
     AS_IF([test "x$wm_cv_libm_pi" != "xyes"],
        [CFLAGS="$CFLAGS $wm_cv_libm_pi"]) ])
AC_CACHE_CHECK([if sinf+cosf are defined in math.h], [wm_cv_libm_sinf],
    [wm_cv_libm_sinf="no"
     wm_save_CFLAGS="$CFLAGS"
     wm_save_LIBS="$LIBS"
     LIBS="$LIBS $LIBM"
     for wm_arg in dnl
       "% yes" dnl natively available (C99 compliant)
       "-D_XOPEN_SOURCE=600" ; dnl Explicit request
     do
       CFLAGS="$wm_save_CFLAGS `echo "$wm_arg" | sed -e 's, *%.*$,,' `"
       AC_LINK_IFELSE([AC_LANG_PROGRAM([dnl
@%:@include <math.h>
], [dnl
  float a, b;

  a = WM_PI;
  b = sqrtf(a);
  a = atan2f(a, b);
  b = cosf(a);
  a = sinf(b);
  a = powf(a, b);
  return (int)a;])],
           [wm_cv_libm_sinf="`echo "$wm_arg" | sed -e 's,^.*% *,,' `" ; break])
     done
     LIBS="$wm_save_LIBS"
     CFLAGS="$wm_save_CFLAGS"])
AS_IF([test "x$wm_cv_libm_sinf" != "xno"],
    [AC_DEFINE([HAVE_FLOAT_MATHFUNC], [1],
        [Defined if the 'float'-typed math function are available (sinf, cosf)])
     AS_IF([test "x$wm_cv_libm_sinf" != "xyes"],
        [CFLAGS="$CFLAGS $wm_cd_libm_sinf"]) ])
AC_SUBST(LIBM) dnl
])
