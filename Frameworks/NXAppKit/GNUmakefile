#
# GNUmakefile
#
GNUSTEP_INSTALLATION_DOMAIN = SYSTEM
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = NXAppKit
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
	NXIconBadge.m \
	NXProgressBar.m \
	NXProgressPie.m \
	NXProgressView.m \
	NXSizer.m \
	NXSplitView.m \
	NXNumericField.m \
	NXUtilities.m \
	NXAlert.m

$(FRAMEWORK_NAME)_HEADER_FILES = \
	NXAppKit.h \
	NXClockView.h \
	NXIcon.h \
	NXIconLabel.h \
	NXIconView.h \
	NXIconBadge.h \
	NXProgressBar.h \
	NXProgressPie.h \
	NXProgressView.h \
	NXSizer.h \
	NXSplitView.h \
	NXNumericField.h \
	NXUtilities.h \
	NXAlert.h

$(FRAMEWORK_NAME)_RESOURCE_FILES = \
	Resources/Images \
	Resources/Fonts \
	Resources/Sounds

$(FRAMEWORK_NAME)_LOCALIZED_RESOURCE_FILES = clockbits.tiff NXAlertPanel.gorm
$(FRAMEWORK_NAME)_LANGUAGES = \
	English French German Italian Spanish \
	Ukrainian Russian Dutch Slovak Hungarian

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble
