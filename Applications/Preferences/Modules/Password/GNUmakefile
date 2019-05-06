# -*- mode: makefile-gmake -*-

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Password
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Password
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_RESOURCE_FILES = \
	$(wildcard Resources/*.tiff) \
	Resources/bundle.registry

$(BUNDLE_NAME)_OBJC_FILES= \
	Password.m

$(BUNDLE_NAME)_HEADERS= \
	Password.h

$(BUNDLE_NAME)_LANGUAGES = \
	English

$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES= \
	Password.gorm

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
