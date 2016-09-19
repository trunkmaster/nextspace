#
# GNUmakefile
#
GNUSTEP_INSTALLATION_DOMAIN = SYSTEM
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = NXAppKitDemo

FRAMEWORK_NAME = NXAppKit
VERSION = 0.6
$(FRAMEWORK_NAME)_CURRENT_VERSION_NAME = 0.6
$(FRAMEWORK_NAME)_DEPLOY_WITH_CURRENT_VERSION = yes
#$(FRAMEWORK_NAME)_HEADER_FILES_DIR = ./
#$(FRAMEWORK_NAME)_LIBRARIES_DEPEND_UPON += $(OBJC_LIBS) $(FND_LIBS) $(GUI_LIBS)

# $(wildcard *.m)
$(FRAMEWORK_NAME)_OBJC_FILES = \
	NXClockView.m \
	NXIcon.m \
	NXIconLabel.m \
	NXIconView.m \
	NXProgressBar.m \
	NXProgressPie.m \
	NXProgressView.m \
	NXSizer.m \
	NXSplitView.m \
	NXNumericField.m \
	NXUtilities.m

$(FRAMEWORK_NAME)_HEADER_FILES = \
	NXAppKit.h \
	NXClockView.h \
	NXIcon.h \
	NXIconLabel.h \
	NXIconView.h \
	NXProgressBar.h \
	NXProgressPie.h \
	NXProgressView.h \
	NXSizer.h \
	NXSplitView.h \
	NXNumericField.h \
	NXUtilities.h

#$(FRAMEWORK_NAME)_RESOURCE_FILES=$(wildcard Images/*)

$(FRAMEWORK_NAME)_LOCALIZED_RESOURCE_FILES = clockbits.tiff
$(FRAMEWORK_NAME)_LANGUAGES = English French German Italian Spanish Ukrainian Russian

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble
