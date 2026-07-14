#   GNUmakefile 
#
#   Copyright (C) 1999 Free Software Foundation, Inc.
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

PALETTE_NAME = 3Containers
3Containers_PALETTE_ICON = ContainersPalette

3Containers_PRINCIPAL_CLASS = ContainersPalette

3Containers_OBJC_FILES = \
	ContainersPalette.m \
	inspectors.m \
	GormNSBrowser.m \
	GormNSTableView.m \
	GormTableViewEditor.m \
	GormTabViewEditor.m \
	GormNSOutlineView.m \
	GormBrowserAttributesInspector.m \
	GormTabViewAttributesInspector.m \
	GormTableColumnAttributesInspector.m \
	GormTableColumnSizeInspector.m \
	GormTableViewAttributesInspector.m \
	GormTableViewSizeInspector.m

3Containers_RESOURCE_FILES = \
	ContainersPalette.tiff \
	GormNSBrowserInspector.gorm \
	GormNSTableViewInspector.gorm \
	GormNSTableColumnInspector.gorm \
	GormNSTableColumnSizeInspector.gorm \
	GormTabViewInspector.gorm \
	palette.table

3Containers_STANDARD_INSTALL = no

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/palette.make

-include GNUmakefile.postamble

