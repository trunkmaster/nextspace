# wm_libexif.m4 - Macros to check proper libexif
#
# Copyright (c) 2014 Window Maker Team
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


# WM_CHECK_LIBEXIF
# ----------------
#
# Checks the needed library link flags
# Sets variable LIBEXIF with the appropriates flags
AC_DEFUN_ONCE([WM_CHECK_LIBEXIF],
[AC_CHECK_HEADER([libexif/exif-data.h],
	[AC_CHECK_FUNC(exif_data_new_from_file,
		[LIBEXIF=],
    		[AC_CHECK_LIB(exif, [exif_data_new_from_file],
		[LIBEXIF=-lexif],
		[AC_MSG_WARN(Could not find EXIF library, you may experience problems)
		LIBEXIF=] )] )],
	[AC_MSG_WARN([header for EXIF library not found])])
AC_SUBST(LIBEXIF) dnl
])
