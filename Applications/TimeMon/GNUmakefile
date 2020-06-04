# -*- mode: makefile-gmake -*-

GNUSTEP_INSTALLATION_DOMAIN = LOCAL
include $(GNUSTEP_MAKEFILES)/common.make

# The application to be compiled
VERSION = 4.2
PACKAGE_NAME = TimeMon
APP_NAME = TimeMon
TimeMon_MAIN_MODEL_FILE = TimeMon.gorm
TimeMon_APPLICATION_ICON = TM-app.tiff

# The Objective-C source files to be compiled
TimeMon_OBJC_FILES = \
	NSColorExtensions.m \
	Percentages.m \
	TimeMonColors.m \
	TimeMon_main.m \
	TimeMonWraps.m

TimeMon_C_FILES = \
	loadave.c

# The Resource files to be copied into the app's resources directory
TimeMon_RESOURCE_FILES = \
	English.lproj/TimeMon.gorm \
	TM-app.tiff \
	TimeMonP.tiff \
	README.rtf

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
