#
#  Tools makefile for NX Tools
#  Copyright (C) 2020 Free Software Foundation, Inc.
#
#  Written by: onflapp
#
#  This file is part of the NEXTSPACE project.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public
#  License along with this library; if not, write to the Free
#  Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#  Boston, MA 02111 USA.

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

PACKAGE_NAME = nxtools

include $(GNUSTEP_MAKEFILES)/common.make

# Manual pages to install
MAN1_PAGES = nxworkspace.1 nxpasteboard.1

# The application to be compiled
TOOL_NAME = nxworkspace nxpasteboard

# The source files to be compiled
nxworkspace_OBJC_FILES = nxworkspace.m
nxpasteboard_OBJC_FILES = nxpasteboard.m

include GNUMakefile.preamble

include $(GNUSTEP_MAKEFILES)/tool.make

include GNUMakefile.postamble
