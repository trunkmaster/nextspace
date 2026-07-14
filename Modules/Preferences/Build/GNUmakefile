#
# GNUmakefile - Build preferences
#
PACKAGE_NAME = Build
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = Build
BUNDLE_EXTENSION = .preferences
Build_PRINCIPAL_CLASS = PCBuildPrefs


#
# Additional libraries
#
Build_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
Build_RESOURCE_FILES= \
  Resources/BuildPrefs.gorm \
  Resources/Info.table

#
# Header files
#
Build_HEADERS= \
  PCBuildPrefs.h

#
# Class files
#
Build_OBJC_FILES= \
  PCBuildPrefs.m

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make

