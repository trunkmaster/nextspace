include $(GNUSTEP_MAKEFILES)/common.make
#
# Application
#
VERSION = 0.1
PACKAGE_NAME = Player
APP_NAME = Player
Player_APPLICATION_ICON = 
GNUSTEP_INSTALLATION_DOMAIN = LOCAL

#
# Resource files
#
Player_RESOURCE_FILES = \
	Resources/Player.gorm \
	Resources/PlayerWindow.gorm

#
# Objective-C Class files
#
Player_OBJC_FILES = \
	AppController.m \
	Player.m

#
# Other sources
#
Player_OBJC_FILES += \
	Player_main.m 

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
