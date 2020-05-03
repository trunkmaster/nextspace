# wm_prog_cc_c11.m4 - Macros to see if compiler may support STD C11
#
# Copyright (c) 2013 Christophe CURIS
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


# WM_PROG_CC_C11
# --------------
#
# Check if the compiler supports C11 standard natively, or if any
# option may help enabling the support
# This is (in concept) similar to AC_PROG_CC_C11, which is unfortunately
# not yet available in autotools; as a side effect we only check for
# compiler's acknowledgement and a few features instead of full support
AC_DEFUN_ONCE([WM_PROG_CC_C11],
[AC_CACHE_CHECK([for C11 standard support], [wm_cv_prog_cc_c11],
    [wm_cv_prog_cc_c11=no
     wm_save_CFLAGS="$CFLAGS"
     for wm_arg in dnl
"% native"   dnl
"-std=c11"
     do
         CFLAGS="$wm_save_CFLAGS `echo $wm_arg | sed -e 's,%.*,,' `"
         AC_COMPILE_IFELSE(
             [AC_LANG_PROGRAM([], [dnl
#if __STDC_VERSION__ < 201112L
fail_because_stdc_version_is_older_than_C11;
#endif
])],
             [wm_cv_prog_cc_c11="`echo $wm_arg | sed -e 's,.*% *,,' `" ; break])
     done
     CFLAGS="$wm_save_CFLAGS"])
AS_CASE([$wm_cv_prog_cc_c11],
    [no|native], [],
    [CFLAGS="$CFLAGS $wm_cv_prog_cc_c11"])
])


# WM_PROG_CC_NESTEDFUNC
# ---------------------
#
# Check if the compiler support declaring Nested Functions (that means
# declaring a function inside another function).
#
# If the compiler does not support them, then the Automake conditional
# USE_NESTED_FUNC will be set to false, in which case the Makefile will
# use the script 'scripts/nested-func-to-macro.sh' to generate a modified
# source with the nested function transformed into a Preprocessor Macro.
AC_DEFUN_ONCE([WM_PROG_CC_NESTEDFUNC],
[AC_CACHE_CHECK([if compiler supports nested functions], [wm_cv_prog_cc_nestedfunc],
    [AC_COMPILE_IFELSE(
        [AC_LANG_SOURCE([[
int main(int narg, char **argv)
{
	int local_variable;

	int nested_function(int argument)
	{
		/* Checking we have access to upper level's scope, otherwise it is of no use */
		return local_variable + argument;
	}

	/* To avoid a warning for unused parameter, that may falsely fail */
	(void) argv;

	/* Initialise using the parameter to main so the compiler won't be tempted to optimise too much */
	local_variable = narg + 1;

	return nested_function(2);
}]]) ],
        [wm_cv_prog_cc_nestedfunc=yes],
        [wm_cv_prog_cc_nestedfunc=no]) ])
AM_CONDITIONAL([USE_NESTED_FUNC], [test "x$wm_cv_prog_cc_nestedfunc" != "xno"])dnl
])
