
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = BrowserViewer
BUNDLE_EXTENSION = .viewer

$(BUNDLE_NAME)_OBJC_FILES = $(wildcard *.m)
$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES = BrowserViewer.gorm
$(BUNDLE_NAME)_LANGUAGES = English
$(BUNDLE_NAME)_STANDARD_INSTALL = no

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
