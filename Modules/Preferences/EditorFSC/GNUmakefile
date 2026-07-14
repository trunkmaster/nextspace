#
# GNUmakefile - EditorFSC preferences
#
PACKAGE_NAME = EditorFSC
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = EditorFSC
BUNDLE_EXTENSION = .preferences
EditorFSC_PRINCIPAL_CLASS = PCEditorFSCPrefs


#
# Additional libraries
#
EditorFSC_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
EditorFSC_RESOURCE_FILES= \
  Resources/EditorFSCPrefs.gorm \
  Resources/Info.table

#
# Header files
#
EditorFSC_HEADERS= \
  PCEditorFSCPrefs.h

#
# Class files
#
EditorFSC_OBJC_FILES= \
  PCEditorFSCPrefs.m

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make

