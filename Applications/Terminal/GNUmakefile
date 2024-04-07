# copyright 2002, 2003 Alexander Malmberg <alexander@malmberg.org>
#
# This file is a part of Terminal.app. Terminal.app is free software; you
# can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation; version 2
# of the License. See COPYING or main.m for more information.


GNUSTEP_INSTALLATION_DOMAIN = LOCAL
include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Terminal
PACKAGE_NAME = Terminal
VERSION = 0.98
Terminal_APPLICATION_ICON = Terminal.tiff
Terminal_MAIN_MODEL_FILE = Terminal.gorm

SUBPROJECTS = Preferences

Terminal_OBJC_FILES = \
	main.m \
	Controller.m \
	\
	Defaults.m\
	\
	SetTitlePanel.m\
	\
	TerminalServices.m \
	TerminalServicesPanel.m \
	\
	TerminalWindow.m \
	TerminalView.m \
	TerminalParser_Linux.m \
	\
	InfoPanel.m\
	\
	TerminalFinder.m \
	TerminalIcon.m \

Terminal_LANGUAGES = English
Terminal_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings \
	Terminal.gorm \
	SetTitlePanel.gorm \
	TerminalServices.gorm \
	SaveAsAccessory.gorm \
	AddArguments.gorm \
	Info.gorm \
	Find.gorm

Terminal_RESOURCE_FILES = \
	Preferences/Preferences.bundle \
	Resources/ExampleServices.svcs \
	Resources/Terminal.tiff \
	Resources/ScrollingMach.tiff \
	Resources/ScrollingOutput.tiff

MAKE_STRINGS_OPTIONS = --aggressive-match --aggressive-remove

ADDITIONAL_OBJCFLAGS += -Wall -D$(subst -,_,$(GNUSTEP_HOST_OS)) -Wno-pointer-sign

# Useful warnings:
#	-W -Wformat=2 -Wno-sign-compare -Wpointer-arith \
#	-Wbad-function-cast -Wcast-align -Wwrite-strings -Wstrict-prototypes \
#	-Wmissing-prototypes -Wmissing-declarations \
#	-Wnested-externs -Wno-unused-parameter

Terminal_LDFLAGS = -lutil -lDesktopKit -lSystemKit -lX11 -ldispatch

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
