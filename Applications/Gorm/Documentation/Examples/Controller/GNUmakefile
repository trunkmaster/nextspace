#
# GNUmakefile 
#
#
# Put all of your customisations in GNUmakefile.preamble and
# GNUmakefile.postamble
#

include $(GNUSTEP_MAKEFILES)/common.make

#
# Main application
#

PACKAGE_NAME=Controller

APP_NAME=Controller
Controller_MAIN_MODEL_FILE=MainMenu.gorm

#
# Additional libraries
#

ADDITIONAL_GUI_LIBS += 

#
# Resource files
#

Controller_RESOURCE_FILES= \
MainMenu.gorm \
Controller.gorm

#
# Header files
#

Controller_HEADERS= \
MyController.h \
WinController.h

#
# Class files
#

Controller_OBJC_FILES= \
main.m \
MyController.m \
WinController.m

#
# C files
#

Controller_C_FILES= 

#
# Subprojects
#

SUBPROJECTS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
