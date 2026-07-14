#
# GNUmakefile - FrameworkProject
#
PACKAGE_NAME = ProjectCenter
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = Framework
BUNDLE_EXTENSION = .project
Framework_PRINCIPAL_CLASS = PCFrameworkProject


#
# Additional libraries
#
Framework_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
Framework_RESOURCE_FILES= \
  Resources/PC.project \
  Resources/Inspector.gorm \
  Resources/Info.table

#
# Header files
#
Framework_HEADERS= \
  PCFrameworkProject.h 

#
# Class files
#
Framework_OBJC_FILES= \
  PCFrameworkProject.m 

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make
