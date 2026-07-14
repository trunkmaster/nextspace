#
# GNUmakefile - ToolProject
#
PACKAGE_NAME = ProjectCenter
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = Tool
BUNDLE_EXTENSION = .project
Tool_PRINCIPAL_CLASS = PCToolProject

#
# Additional libraries
#
Tool_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
Tool_RESOURCE_FILES= \
  Resources/PC.project \
  Resources/main.m \
  Resources/Inspector.gorm \
  Resources/Info.table \
  Resources/Info.gnustep

#
# Header files
#
Tool_HEADERS= \
  PCToolProject.h 

#
# Class files
#
Tool_OBJC_FILES= \
  PCToolProject.m 

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make
