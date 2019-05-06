# -*- mode: makefile-gmake -*-

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Display
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = DisplayPrefs
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_OBJC_FILES= \
	Display.m

$(BUNDLE_NAME)_HEADERS= \
	Display.h

$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/Monitor.tiff \
	Resources/bundle.registry

$(BUNDLE_NAME)_LANGUAGES = \
	English
$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES= Display.gorm

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
