# -*- mode: makefile-gmake -*-

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Localization
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Localization
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_LANGUAGES = \
	English

$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES = \
	Localization.gorm

$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/Localization.tiff \
	Resources/bundle.registry \
	Resources/languages.list \
	Resources/languages-encodings.list

$(BUNDLE_NAME)_OBJC_FILES= \
	Localization.m \
	LanguageList.m

$(BUNDLE_NAME)_HEADERS= \
	Localization.h

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
