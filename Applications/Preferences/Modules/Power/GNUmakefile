# -*- mode: makefile-gmake -*-

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Power
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Power
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_OBJC_FILES= \
	Power.m

$(BUNDLE_NAME)_HEADERS= \
	Power.h

$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/Power.tiff \
	Resources/bundle.registry

$(BUNDLE_NAME)_LANGUAGES = \
	English
$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES= Power.gorm

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
