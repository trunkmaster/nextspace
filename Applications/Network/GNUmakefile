# -*- mode: makefile-gmake -*-

GNUSTEP_INSTALLATION_DOMAIN = LOCAL
include $(GNUSTEP_MAKEFILES)/common.make

# Application
VERSION = 0.1
PACKAGE_NAME = Network
APP_NAME = Network
Network_APPLICATION_ICON = eunet.tiff
Network_MAIN_MODEL_FILE = Network.gorm

# Test
SUBPROJECTS = Test

# Resource files
Network_RESOURCE_FILES = \
	Resources/eunet.tiff \
	Resources/net.tiff \
	Resources/asianet.tiff

# Localization
Network_LANGUAGES = English
Network_LOCALIZED_RESOURCE_FILES = \
	Network.gorm \
	EthernetView.gorm \
	AddConnection.gorm

#
# Header files
#
Network_HEADER_FILES = \
	AppController.h \
	EthernetController.h

#
# Class files
#
Network_OBJC_FILES = \
	AppController.m \
	ConnectionManager.m \
	EthernetController.m

#
# Other sources
#
Network_OBJC_FILES += \
	Network_main.m 

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
