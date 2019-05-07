include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN = LOCAL

APP_NAME=			TextEdit
PACKAGE_NAME=			TextEdit
TextEdit_PRINCIPAL_CLASS=	NSApplication
TextEdit_APPLICATION_ICON=	Edit.tiff

#
# Resource files
#
TextEdit_MAIN_MODEL_FILE=	Edit.gorm
TextEdit_RESOURCE_FILES= \
	Edit.tiff \
	EditTitle.tiff \
	Encodings.txt \
	rtf.tiff \
	rtfd.tiff \
	text.tiff

TextEdit_LOCALIZED_RESOURCE_FILES= \
	Document.gorm \
	Edit.gorm \
	FindPanel.gorm \
	Info.gorm \
	EncodingAccessory.gorm \
	Preferences.gorm \
	FindPanel.strings \
	Localizable.strings

TextEdit_LANGUAGES= English

#
# Source
#
TextEdit_HEADER_FILES= \
	Controller.h \
	Document.h \
	DocumentReadWrite.h \
	MultiplePageView.h \
	Preferences.h \
	ScalingScrollView.h \
	TextFinder.h

TextEdit_OBJC_FILES= \
	Controller.m \
	Document.m \
	DocumentReadWrite.m \
	MultiplePageView.m \
	Preferences.m \
	ScalingScrollView.m \
	TextFinder.m

TextEdit_OBJC_FILES += Edit_main.m

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/application.make

-include GNUmakefile.postamble
