#  GNUmakefile
#
#  Copyright (C) 2011 Sergii Stoian
#  Copyright (C) 2005 Saso Kiselkov
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = Workspace
VERSION = 0.8
#REVISION = "`git log -n 1 --date=short --format=format:"%ad.%h"`"
REVISION = "`git log -n 1 --date=short --format=format:"%h, %ad"`"
APP_NAME = Workspace

SUBPROJECTS = \
	Viewers/BrowserViewer \
	Inspectors \
	$(wildcard Preferences/*) \
	Tools/FileMover \
	Tools/Sizer
#	WindowMaker/Tools
#	Viewers/IconsViewer \

$(APP_NAME)_OBJC_FILES = \
	$(wildcard *.m) \
	$(wildcard Viewers/*.m) \
	$(wildcard Operations/*.m) \
	$(wildcard Processes/*.m)

$(APP_NAME)_RESOURCE_FILES = \
	$(wildcard Resources/*) \
	Inspectors/Inspectors.bundle \
	$(wildcard Processes/English.lproj)

# WindowMaker
# Commandline option to make it separate application: windowmaker=yes
ifneq ($(windowmaker), no)
  WM_DIR = WindowMaker
  include GNUmakefile.WM
endif

$(APP_NAME)_LOCALIZED_RESOURCE_FILES = $(notdir $(wildcard English.lproj/*))

$(APP_NAME)_LANGUAGES = $(basename $(wildcard *.lproj))

$(APP_NAME)_HEADER_FILES = Inspectors/Workspace.h
$(APP_NAME)_HEADER_FILES_INSTALL_DIR = $(GNUSTEP_SYSTEM_HEADERS)/Applications

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
include $(GNUSTEP_MAKEFILES)/Instance/Shared/headers.make
-include GNUmakefile.postamble
