# -*- mode: makefile-gmake -*-

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME =		Font
BUNDLE_EXTENSION =	.preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Font
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_LANGUAGES = English

$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES = \
	Fonts.gorm \
	Localizable.strings

$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/FontPreferences.tiff \
	Resources/bundle.registry

$(BUNDLE_NAME)_OBJC_FILES = Font.m

$(BUNDLE_NAME)_HEADERS = Font.h


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
