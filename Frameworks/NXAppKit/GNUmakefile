#
# GNUmakefile
#
GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

include $(GNUSTEP_MAKEFILES)/common.make

FRAMEWORK_NAME = NXAppKit
VERSION = 0.3
$(FRAMEWORK_NAME)_CURRENT_VERSION_NAME = 0.3
$(FRAMEWORK_NAME)_DEPLOY_WITH_CURRENT_VERSION = yes
#$(FRAMEWORK_NAME)_HEADER_FILES_DIR = ./
#$(FRAMEWORK_NAME)_LIBRARIES_DEPEND_UPON += $(OBJC_LIBS) $(FND_LIBS) $(GUI_LIBS)

# $(wildcard *.m)
$(FRAMEWORK_NAME)_OBJC_FILES = \
	NXIcon.m \
	NXIconLabel.m \
	NXIconView.m \
	NXSplitView.m \
	NXProgressView.m \
	NXProgressBar.m \
	NXProgressPie.m \
	NXSizer.m \
	NXClockView.m \
	NXUtilities.m

$(FRAMEWORK_NAME)_HEADER_FILES = \
	NXAppKit.h \
	NXIcon.h \
	NXIconLabel.h \
	NXIconView.h \
	NXSplitView.h \
	NXProgressView.h \
	NXProgressBar.h \
	NXProgressPie.h \
	NXSizer.h \
	NXClockView.h \
	NXUtilities.h

#$(FRAMEWORK_NAME)_RESOURCE_FILES=$(wildcard Images/*)

$(FRAMEWORK_NAME)_LOCALIZED_RESOURCE_FILES = clockbits.png
$(FRAMEWORK_NAME)_LANGUAGES = English

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
-include GNUmakefile.postamble
