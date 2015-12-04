include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Password
BUNDLE_EXTENSION = .preferences

BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/Preferences

$(BUNDLE_NAME)_LANGUAGES = \
	English

$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES= \
	Password.gorm

$(BUNDLE_NAME)_RESOURCE_FILES = \
	$(wildcard Resources/*.tiff)

$(BUNDLE_NAME)_OBJC_FILES= \
	Password.m

$(BUNDLE_NAME)_HEADERS= \
	Password.h

$(BUNDLE_NAME)_PRINCIPAL_CLASS= \
	Password

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
