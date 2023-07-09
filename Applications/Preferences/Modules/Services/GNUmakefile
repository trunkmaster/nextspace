include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
VERSION = 0.1
PACKAGE_NAME = Services
BUNDLE_NAME = Services
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Services
$(BUNDLE_NAME)_STANDARD_INSTALL = no

#
# Header files
#
$(BUNDLE_NAME)_HEADER = \
	Services.h

#
# Class files
#
$(BUNDLE_NAME)_OBJC_FILES = \
	Services.m

#
# Resource files
#
$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/Services.tiff \
	Resources/bundle.registry

#
# Languages
#
$(BUNDLE_NAME)_LANGUAGES = \
	English

#
# Interface GUI
#
$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES= \
	Services.gorm

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
