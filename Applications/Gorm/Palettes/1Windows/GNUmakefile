#   GNUmakefile 
#
#   Copyright (C) 1999-2005 Free Software Foundation, Inc.
#
#   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
#   Date: 1999
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
#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

PACKAGE_NAME = gorm
include $(GNUSTEP_MAKEFILES)/common.make

PALETTE_NAME = 1Windows
1Windows_PALETTE_ICON = WindowsPalette

1Windows_OBJC_FILES = \
	WindowsPalette.m \
	GormDrawerAttributesInspector.m \
	GormWindowAttributesInspector.m\
	GormWindowSizeInspector.m \
	inspectors.m

1Windows_HEADER_FILES = \
	GormNSWindow.h \
	GormWindowAttributesInspector.h\
        GormWindowSizeInspector.h\
	GormNSPanel.h \
	WindowsPalette.h

1Windows_PRINCIPAL_CLASS = WindowsPalette

1Windows_RESOURCE_FILES = \
	WindowsPalette.tiff \
	WindowDrag.tiff \
	Drawer.tiff \
	DrawerSmall.tiff \
	GormDrawerAttributesInspector.gorm \
	GormNSWindowSizeInspector.gorm \
	GormNSWindowInspector.gorm \
	palette.table

1Windows_STANDARD_INSTALL = no

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/palette.make

-include GNUmakefile.postamble

