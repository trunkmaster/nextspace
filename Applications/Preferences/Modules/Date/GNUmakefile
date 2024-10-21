include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
VERSION = 0.1
PACKAGE_NAME = Date
BUNDLE_NAME = Date
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Date
$(BUNDLE_NAME)_STANDARD_INSTALL = no

#
# Header files
#
$(BUNDLE_NAME)_HEADER = \
	Date.h \
	Calendar.h \
	TimeView.h

#
# Class files
#
$(BUNDLE_NAME)_OBJC_FILES = \
	Date.m \
	Calendar.m \
	TimeView.m

#
# Resource files
#
$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/Date.tiff \
	Resources/days.tiff \
	Resources/daysH.tiff \
	Resources/world.tiff \
	Resources/weeks.tiff \
	Resources/weeksMonday.tiff \
	Resources/clockbits.tiff \
	Resources/bundle.registry

#
# Languages
#
$(BUNDLE_NAME)_LANGUAGES = \
	English

#
# Interface GUI
#
$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES= \
	Date.gorm

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
