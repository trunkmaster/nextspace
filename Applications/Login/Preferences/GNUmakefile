include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Login
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Login
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_LANGUAGES = \
	English

$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES= \
	Login.gorm

$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/Loginwindow.tiff \
	Resources/bundle.registry

$(BUNDLE_NAME)_OBJC_FILES= \
	Login.m

$(BUNDLE_NAME)_HEADERS= \
	Login.h

$(BUNDLE_NAME)_PRINCIPAL_CLASS= \
	Login

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
