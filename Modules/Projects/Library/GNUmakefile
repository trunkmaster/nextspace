#
# GNUmakefile - LibraryProject
#
PACKAGE_NAME = ProjectCenter
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = Library
BUNDLE_EXTENSION = .project
Library_PRINCIPAL_CLASS = PCLibProject


#
# Additional libraries
#
Library_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
Library_RESOURCE_FILES= \
  Resources/PC.project \
  Resources/Version \
  Resources/Inspector.gorm \
  Resources/Info.table

#
# Header files
#
Library_HEADERS= \
  PCLibProject.h 

#
# Class files
#
Library_OBJC_FILES= \
  PCLibProject.m 

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make
