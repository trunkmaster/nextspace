
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = ImageInspector
BUNDLE_EXTENSION = .inspector

$(BUNDLE_NAME)_OBJC_FILES = $(wildcard *.m)
$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES = ImageInspector.gorm
$(BUNDLE_NAME)_LANGUAGES = English
$(BUNDLE_NAME)_STANDARD_INSTALL = yes

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
