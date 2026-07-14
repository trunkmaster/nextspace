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

PACKAGE_NAME=SimpleApp

APP_NAME=SimpleApp
SimpleApp_MAIN_MODEL_FILE=MainMenu.gorm

#
# Additional libraries
#

ADDITIONAL_GUI_LIBS += 

#
# Resource files
#

SimpleApp_RESOURCE_FILES= \
MainMenu.gorm 

#
# Header files
#

SimpleApp_HEADERS= \
MyController.h

#
# Class files
#

SimpleApp_OBJC_FILES= \
main.m \
MyController.m 

#
# C files
#

SimpleApp_C_FILES= 

#
# Subprojects
#

SUBPROJECTS = 

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
