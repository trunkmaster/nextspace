# -*- mode: makefile-gmake -*-

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Screen
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = ScreenPreferences
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_OBJC_FILES= \
	Screen.m \
	ScreenCanvas.m \
	DisplayBox.m

$(BUNDLE_NAME)_HEADERS= \
	Screen.h

$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/Screen.tiff \
	Resources/appiconyard.tiff \
	Resources/iconyard.tiff \
	Resources/dock.tiff \
	Resources/bundle.registry

$(BUNDLE_NAME)_LANGUAGES = \
	English
$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES= Screen.gorm

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
