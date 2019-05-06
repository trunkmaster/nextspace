# -*- mode: makefile-gmake -*-

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Mouse
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Mouse
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_LANGUAGES = \
	English

$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES= \
	Mouse.gorm

$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/Mouse.tiff \
	Resources/bundle.registry

$(BUNDLE_NAME)_OBJC_FILES= \
	Mouse.m

$(BUNDLE_NAME)_HEADERS= \
	Mouse.h

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
