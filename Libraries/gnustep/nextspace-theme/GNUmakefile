# Requires NextSpace's Cairo backend
# Set by: 'defaults write NSGlobalDomain GSTheme NextSpace'

include $(GNUSTEP_MAKEFILES)/common.make

#GNUSTEP_INSTALLATION_DOMAIN=USER

PACKAGE_NAME = NextSpace
BUNDLE_NAME = NextSpace
BUNDLE_EXTENSION = .theme
VERSION = 0.95

$(BUNDLE_NAME)_INSTALL_DIR=$(GNUSTEP_LIBRARY)/Themes
$(BUNDLE_NAME)_PRINCIPAL_CLASS = NextSpace

$(BUNDLE_NAME)_OBJC_FILES = \
	NextSpace.m \
	NXTScrollerKnobSlotCell.m

$(BUNDLE_NAME)_RESOURCE_FILES = \
	Resources/*.tiff \
	Resources/ThemeImages

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

