#   GNUmakefile: main makefile for Gorm palettes
#
#   Copyright (C) 1999 Free Software Foundation, Inc.
#
#   Author:  Gregory John Casamento
#   Date: 2007
#   
#   This file is part of GNUstep.
#   
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
#

PACKAGE_NAME = gorm
include $(GNUSTEP_MAKEFILES)/common.make

#
# Each palette is a subproject
#
SUBPROJECTS = \
	Gorm \
	Nib \
	GModel \
	Xib

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble

