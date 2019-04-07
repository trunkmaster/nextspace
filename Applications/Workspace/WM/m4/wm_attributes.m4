# wm_attributes.m4 - Macros to check compiler attributes and define macros
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


# WM_C_NORETURN
# -------------
#
# Checks if the compiler supports ISO C11 noreturn attribute, if not
# try to define the keyword to a known syntax that does the job, or
# if nothing works sets it to empty to, at least, be able to
# compile the sources
AC_DEFUN_ONCE([WM_C_NORETURN],
[AC_REQUIRE([_WM_SHELLFN_FUNCATTR])
AC_CACHE_CHECK([for noreturn], [wm_cv_c_noreturn],
    [wm_cv_c_noreturn=no
     AC_COMPILE_IFELSE(
      [AC_LANG_PROGRAM(
          [#include <unistd.h>
#include <stdnoreturn.h>

/* Attribute in the prototype of the function */
noreturn int test_function(void);

/* Attribute on the function itself */
noreturn int test_function(void) {
  _exit(1);
}
], [  test_function();])],
          [wm_cv_c_noreturn=stdnoreturn],
          [for wm_attr in  dnl
             "__attribute__((noreturn))"   dnl for modern GCC-like compilers
             "__attribute__((__noreturn__))"   dnl for older GCC-like compilers
             "__declspec(noreturn)"   dnl for some other compilers
           ; do
             AS_IF([wm_fn_c_try_compile_funcattr "$wm_attr"],
                 [wm_cv_c_noreturn="$wm_attr" ; break])
           done]) dnl
    ])
AS_CASE([$wm_cv_c_noreturn],
    [stdnoreturn],
        [AC_DEFINE([HAVE_STDNORETURN], 1,
            [Defined if header "stdnoreturn.h" exists, it defines ISO C11 attribute 'noreturn' and it works])],
    [no],
        [AC_DEFINE([noreturn], [],
            [Defines the attribute to tell the compiler that a function never returns, if the ISO C11 attribute does not work])],
    [AC_DEFINE_UNQUOTED([noreturn], [${wm_cv_c_noreturn}],
        [Defines the attribute to tell the compiler that a function never returns, if the ISO C11 attribute does not work])])
])


# _WM_SHELLFN_FUNCATTRIBUTE
# -------------------------
# (internal shell function only!)
#
# Create a shell function to check if we can compile with special
# function attributes
AC_DEFUN([_WM_SHELLFN_FUNCATTR],
[@%:@ wm_fn_c_try_compile_funcattr ATTRIBUTE
@%:@ ---------------------------------------
@%:@ Try compiling a function with the attribute ATTRIBUTE
wm_fn_c_try_compile_funcattr ()
{
  AC_COMPILE_IFELSE(
      [AC_LANG_PROGRAM(
          [
/* Attribute in the prototype of the function */
int test_function(int arg) $[]1;

/* Attribute on the function itself */
$[]1 int test_function(int arg) {
  return arg - 1;
}], [int val;
val = test_function(1);
return val;])],
      [wm_retval=0],
      [wm_retval=1])
  AS_SET_STATUS([$wm_retval])
}
])
