include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME =		Keyboard
BUNDLE_EXTENSION =	.preferences

$(BUNDLE_NAME)_PRINCIPAL_CLASS = Keyboard
$(BUNDLE_NAME)_STANDARD_INSTALL = no

Keyboard_LANGUAGES = \
	English

Keyboard_LOCALIZED_RESOURCE_FILES = \
	Keyboard.gorm

Keyboard_RESOURCE_FILES = \
	Resources/Keyboard.tiff \
	Resources/bundle.registry

Keyboard_OBJC_FILES = \
	Keyboard.m

Keyboard_HEADERS = \
	Keyboard.h

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
