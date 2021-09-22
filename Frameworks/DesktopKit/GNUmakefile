# -*- mode: makefile-gmake -*-

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = DesktopKit
FRAMEWORK_NAME = DesktopKit
VERSION = 0.6
$(FRAMEWORK_NAME)_CURRENT_VERSION_NAME = 0.6
$(FRAMEWORK_NAME)_DEPLOY_WITH_CURRENT_VERSION = yes
#$(FRAMEWORK_NAME)_HEADER_FILES_DIR = ./
#$(FRAMEWORK_NAME)_LIBRARIES_DEPEND_UPON += $(OBJC_LIBS) $(FND_LIBS) $(GUI_LIBS)

# $(wildcard *.m)
$(FRAMEWORK_NAME)_OBJC_FILES = \
	NXTBundle.m \
	NXTDefaults.m \
	NXTFileManager.m \
	\
	NXTClockView.m \
	NXTAlert.m \
	NXTIcon.m \
	NXTIconLabel.m \
	NXTIconView.m \
	NXTIconBadge.m \
	NXTProgressBar.m \
	NXTProgressPie.m \
	NXTProgressView.m \
	NXTSizer.m \
	NXTSplitView.m \
	NXTNumericField.m \
	NXTPanelLoader.m \
	NXTSavePanel.m \
	NXTOpenPanel.m \
	NXTHelpPanel.m \
	NXTListView.m \
	\
	Utilities.m

$(FRAMEWORK_NAME)_HEADER_FILES = \
	DesktopKit.h \
	\
	NXTBundle.h \
	NXTDefaults.h \
	NXTFileManager.h \
	\
	NXTAlert.h \
	NXTClockView.h \
	NXTIcon.h \
	NXTIconLabel.h \
	NXTIconView.h \
	NXTIconBadge.h \
	NXTProgressBar.h \
	NXTProgressPie.h \
	NXTProgressView.h \
	NXTSizer.h \
	NXTSplitView.h \
	NXTNumericField.h \
	NXTSavePanel.h \
	NXTOpenPanel.h \
	NXTHelpPanel.h \
	NXTListView.h \
	\
	Utilities.h

$(FRAMEWORK_NAME)_RESOURCE_FILES = \
	Resources/Images \
	Resources/Fonts \
	Resources/Sounds \
	Resources/25-nextspace-fonts.conf

$(FRAMEWORK_NAME)_LOCALIZED_RESOURCE_FILES = clockbits.tiff \
	NXTAlertPanel.gorm \
	NXTSavePanel.gorm \
	NXTOpenPanel.gorm \
	NXTHelpPanel.gorm
$(FRAMEWORK_NAME)_LANGUAGES = \
	English French German Italian Spanish \
	Ukrainian Russian Dutch Slovak Hungarian

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble
