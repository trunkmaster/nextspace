# wm_i18n.m4 - Macros to check and enable translations in WindowMaker
#
# Copyright (c) 2014-2015 Christophe CURIS
# Copyright (c) 2015 The Window Maker Tean
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
# with this program; see the file COPYING.


# WM_I18N_LANGUAGES
# -----------------
#
# Detect which languages the user wants to be installed and check if
# the gettext environment is available.
#
# The list of languages are provided through the environment variable
# LINGUAS as a space-separated list of ISO 3166 country codes.
# This list is checked against the list of currently available languages
# the sources and a warning is issued if a language is not found.
#
# Support for internationalisation is disabled if the variable is empty
# (or undefined)
#
# The variable 'supported_locales' is created to contain the list of
# languages that will have been detected properly and will be installed
AC_DEFUN_ONCE([WM_I18N_LANGUAGES],
[AC_ARG_VAR([LINGUAS],
    [list of language translations to support (I18N), use 'list' to get the list of supported languages, default: none])dnl
AC_DEFUN([WM_ALL_LANGUAGES],
    [m4_esyscmd([( ls WINGs/po/ ; ls po/ ; ls WPrefs.app/po/ ; ls util/po/ ) | sed -n -e '/po$/{s,\.po,,;p}' | sort -u | tr '\n' ' '])])dnl
dnl We 'divert' the macro to have it executed as soon as the option list have
dnl been processed, so the list of locales will be printed after the configure
dnl options have been parsed, but before any test have been run
m4_divert_text([INIT_PREPARE],
    [AS_IF([test "x$LINGUAS" = "xlist"],
        [AS_ECHO(["Supported languages: WM_ALL_LANGUAGES"])
         AS_EXIT([0])]) ])dnl
AS_IF([test "x$LINGUAS" != "x"],
    [wm_save_LIBS="$LIBS"
     AC_SEARCH_LIBS([gettext], [intl], [],
        [AC_MSG_ERROR([support for internationalization requested, but library for gettext not found])])
     AS_IF([test "x$ac_cv_search_gettext" = "xnone required"],
         [INTLIBS=""],
         [INTLIBS="$ac_cv_search_gettext"])
     AC_CHECK_FUNCS([gettext dgettext], [],
        [AC_MSG_ERROR([support for internationalization requested, but gettext was not found])])
     LIBS="$wm_save_LIBS"
     dnl
     dnl The program 'msgfmt' is needed to convert the 'po' files into 'mo' files
     AC_CHECK_PROG([MSGFMT], [msgfmt], [msgfmt])
     AS_IF([test "x$MSGFMT" = "x"],
         [AC_MSG_ERROR([the program 'msgfmt' is mandatory to install translation - do you miss the package 'gettext'?])])
     dnl
     dnl Environment is sane, let's continue
     AC_DEFINE([I18N], [1], [Internationalization (I18N) support (set by configure)])
     supported_locales=""

     # This is the list of locales that our archive currently supports
     wings_locales=" m4_esyscmd([ls WINGs/po/ | sed -n '/po$/{s,.po,,;p}' | tr '\n' ' '])"
     wmaker_locales=" m4_esyscmd([ls po/ | sed -n '/po$/{s,.po,,;p}' | tr '\n' ' '])"
     wprefs_locales=" m4_esyscmd([ls WPrefs.app/po/ | sed -n '/po$/{s,.po,,;p}' | tr '\n' ' '])"
     util_locales=" m4_esyscmd([ls util/po/ | sed -n '/po$/{s,.po,,;p}' | tr '\n' ' '])"
     man_locales=" m4_esyscmd([ls doc/ | grep '^[a-z][a-z]\(_[A-Z][A-Z]\)*$' | tr '\n' ' '])"

     # If the LINGUAS is specified as a simple '*', then we enable all the languages
     # we know. This is not standard, but it is useful is some cases
     AS_IF([test "x$LINGUAS" = "x*"],
         [LINGUAS="WM_ALL_LANGUAGES"])

     # Check every language asked by user against these lists to know what to install
     for lang in $LINGUAS; do
         found=0
         wm_missing=""
         m4_foreach([REGION], [WINGs, wmaker, WPrefs, util, man],
             [AS_IF([echo "$[]m4_tolower(REGION)[]_locales" | grep " $lang " > /dev/null],
                 [m4_toupper(REGION)MOFILES="$[]m4_toupper(REGION)MOFILES $lang.mo"
                  found=1],
                 [wm_missing="$wm_missing, REGION"])
             ])
         # Locale has to be supported by at least one part to be reported in the end
         # If it is not supported everywhere we just display a message to the user so
         # that he knows about it
         wm_missing="`echo "$wm_missing" | sed -e 's/^, //' `"
         AS_IF([test $found = 1],
             [supported_locales="$supported_locales $lang"
              AS_IF([test "x$wm_missing" != "x"],
                  [AC_MSG_WARN([locale $lang is not supported in $wm_missing])]) ],
             [AC_MSG_WARN([locale $lang is not supported at all, ignoring])])
     done
     #
     # Post-processing the names for the man pages because we are not expecting
     # a "po" file but a directory name in this case
     MANLANGDIRS="`echo $MANMOFILES | sed -e 's,\.mo,,g' `"
],
[INTLIBS=""
 WINGSMOFILES=""
 WMAKERMOFILES=""
 WPREFSMOFILES=""
 UTILMOFILES=""
 MANLANGDIRS=""
 supported_locales=" disabled"])
dnl
dnl The variables that are used in the Makefiles:
AC_SUBST([INTLIBS])dnl
AC_SUBST([WINGSMOFILES])dnl
AC_SUBST([WMAKERMOFILES])dnl
AC_SUBST([WPREFSMOFILES])dnl
AC_SUBST([UTILMOFILES])dnl
AC_SUBST([MANLANGDIRS])dnl
])


# WM_I18N_XGETTEXT
# ----------------
#
# xgettext is used to generate the Templates for translation, it is not
# mandatory for users, only for translation teams. We look for it even
# if I18N was not asked because it can be used by dev team.
AC_DEFUN_ONCE([WM_I18N_XGETTEXT],
[AC_CHECK_PROGS([XGETTEXT], [xgettext], [])
AS_IF([test "x$XGETTEXT" != "x"],
    AS_IF([$XGETTEXT --help 2>&1 | grep "illegal" > /dev/null],
        [AC_MSG_WARN([[$XGETTEXT is not GNU version, ignoring]])
         XGETTEXT=""]))
AM_CONDITIONAL([HAVE_XGETTEXT], [test "x$XGETTEXT" != "x"])dnl
])


# WM_I18N_MENUTEXTDOMAIN
# ----------------------
#
# This option allows user to define a special Domain for translating
# Window Maker's menus. This can be useful because distributions may
# wish to customize the menus, and thus can make them translatable
# with their own po/mo files without having to touch WMaker's stuff.
AC_DEFUN_ONCE([WM_I18N_MENUTEXTDOMAIN],
[AC_ARG_WITH([menu-textdomain],
    [AS_HELP_STRING([--with-menu-textdomain=DOMAIN],
        [specify gettext domain used for menu translations])],
    [AS_CASE([$withval],
        [yes], [AC_MSG_ERROR([you are supposed to give a domain name for '--with-menu-textdomain'])],
        [no],  [menutextdomain=""],
        [menutextdomain="$withval"])],
    [menutextdomain=""])
AS_IF([test "x$menutextdomain" != "x"],
    [AC_DEFINE_UNQUOTED([MENU_TEXTDOMAIN], ["$menutextdomain"],
        [gettext domain to be used for menu translations]) ])
])


dnl WM_I18N_XLOCALE
dnl ---------------
dnl
dnl X11 needs to redefine the function 'setlocale' to properly initialize itself,
dnl we check if user wants to disable this behaviour or if it is not supported
AC_DEFUN_ONCE([WM_I18N_XLOCALE],
[AC_ARG_ENABLE([xlocale],
    [AS_HELP_STRING([--disable-xlocale],
        [disable initialization of locale for X])],
    [AS_CASE([$enableval],
        [yes|no], [],
        [AC_MSG_ERROR([bad value '$enableval' for --disable-xlocale])])],
    [enable_xlocale=auto])
AS_IF([test "x$enable_xlocale" != "xno"],
    [AC_CHECK_LIB([X11], [_Xsetlocale],
        [AC_DEFINE([X_LOCALE], [1],
            [defined if the locale is initialized by X window])],
        [AS_IF([test "x$enable_xlocale" = "xyes"],
            [AC_MSG_ERROR([support for X_LOCALE was explicitely requested, but X11 lacks the appropriate function])])],
        [$XLFLAGS $XLIBS]) ])
])
