#
# GNUmakefile - Saving preferences
#
PACKAGE_NAME = Saving
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = Saving
BUNDLE_EXTENSION = .preferences
Saving_PRINCIPAL_CLASS = PCSavingPrefs


#
# Additional libraries
#
Saving_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
Saving_RESOURCE_FILES= \
  Resources/SavingPrefs.gorm \
  Resources/Info.table

#
# Header files
#
Saving_HEADERS= \
  PCSavingPrefs.h

#
# Class files
#
Saving_OBJC_FILES= \
  PCSavingPrefs.m

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make

