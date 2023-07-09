include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
VERSION = 0.1
PACKAGE_NAME = Menu
BUNDLE_NAME = Menu
BUNDLE_EXTENSION = .preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Menu
$(BUNDLE_NAME)_STANDARD_INSTALL = no

#
# Header files
#
$(BUNDLE_NAME)_HEADER = \
	Menu.h

#
# Class files
#
$(BUNDLE_NAME)_OBJC_FILES = \
	Menu.m

#
# Resource files
#
$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/Menu.tiff \
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
	Menu.gorm

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
