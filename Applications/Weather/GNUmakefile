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

SUBPROJECTS = Forecasts/OpenWeatherMap

#
# Resource files
#
$(APP_NAME)_RESOURCE_FILES = Weather.tiff

#
# Localization
#
$(APP_NAME)_LANGUAGES = English
$(APP_NAME)_LOCALIZED_RESOURCE_FILES = Weather.gorm

#
# Class files
#
$(APP_NAME)_OBJC_FILES = \
	AppController.m \
	WeatherView.m	

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
