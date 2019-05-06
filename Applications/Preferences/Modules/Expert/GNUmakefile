# -*- mode: makefile-gmake -*-

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Expert
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Expert
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_OBJC_FILES= \
	Expert.m \
	WMPermissions.m

$(BUNDLE_NAME)_HEADERS= \
	Expert.h \
	WMPermissions.h

$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/Expert.tiff \
	Resources/bundle.registry

$(BUNDLE_NAME)_LANGUAGES = \
	English
$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES = Expert.gorm

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
