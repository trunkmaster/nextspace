#
# GNUmakefile - ApplicationProject
#
PACKAGE_NAME = ProjectCenter
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = Application
BUNDLE_EXTENSION = .project
Application_PRINCIPAL_CLASS = PCAppProject


#
# Additional libraries
#
Application_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
Application_RESOURCE_FILES= \
  Resources/AppController.h \
  Resources/AppController.m \
  Resources/main.m \
  Resources/PC.project \
  Resources/Main.gorm \
  Resources/Inspector.gorm \
  Resources/Main.gsmarkup \
  Resources/MainMenu-GNUstep.gsmarkup \
  Resources/MainMenu-OSX.gsmarkup \
  Resources/Info.table \
  Resources/Info.gnustep

#
# Header files
#
Application_HEADERS= \
  PCAppProject.h \
  PCAppProject+Inspector.h 

#
# Class files
#
Application_OBJC_FILES= \
  PCAppProject.m \
  PCAppProject+Inspector.m 

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make

