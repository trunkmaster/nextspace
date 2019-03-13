#
# GNUmakefile
#

GNUSTEP_INSTALLATION_DOMAIN = LOCAL
include $(GNUSTEP_MAKEFILES)/common.make

#GNUSTEP_BUILD_DIR = /Users/me/Projects/==BUILD==/Preferences.build

#
# Application
#
VERSION = 0.5
PACKAGE_NAME = Weather
APP_NAME = Weather
$(APP_NAME)_APPLICATION_ICON = Weather.tiff

#SUBPROJECTS =

#
# Resource files
#
$(APP_NAME)_RESOURCE_FILES = Weather.tiff

#
# Localization
#
$(APP_NAME)_LANGUAGES = English
$(APP_NAME)_LOCALIZED_RESOURCE_FILES = \
	$(notdir $(wildcard English.lproj/*.png)) \
	Weather.gorm

#
# Header files
#
#$(APP_NAME)_HEADER_FILES = Prefernces.h
#$(APP_NAME)_HEADER_FILES_INSTALL_DIR = $(GNUSTEP_SYSTEM_HEADERS)/apps

#
# Class files
#
$(APP_NAME)_OBJC_FILES = \
	AppController.m \
	WeatherView.m \
	OWMForecast.m \
	YahooForecast.m 

#
# Other sources
#
$(APP_NAME)_OBJC_FILES += Weather_main.m 

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
