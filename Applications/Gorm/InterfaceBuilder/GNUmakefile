#
# GNUmakefile 
# Written by Gregory John Casamento <greg_casamento@yahoo.com>
#

PACKAGE_NAME = InterfaceBuilder
include $(GNUSTEP_MAKEFILES)/common.make


#
# Subprojects
#



#
# Library
#

PACKAGE_NAME=InterfaceBuilder
LIBRARY_VAR=INTERFACEBUILDER
LIBRARY_NAME=InterfaceBuilder
InterfaceBuilder_HEADER_FILES_DIR=.
InterfaceBuilder_HEADER_FILES_INSTALL_DIR=/InterfaceBuilder
ADDITIONAL_INCLUDE_DIRS = -I..
srcdir = .

include ./Version

#
# Additional libraries
#

InterfaceBuilder_LIBRARIES_DEPEND_UPON += -lgnustep-gui -l$(FOUNDATION_LIBRARY_NAME)

#
# Header files
#

InterfaceBuilder_HEADER_FILES= \
IBApplicationAdditions.h \
IBCellAdditions.h \
IBCellProtocol.h \
IBConnectors.h \
IBDefines.h \
IBDocuments.h \
IBEditors.h \
IBInspector.h \
IBInspectorManager.h \
IBInspectorMode.h \
IBObjectAdditions.h \
IBObjectProtocol.h \
IBPalette.h \
IBPlugin.h \
IBProjects.h \
IBProjectFiles.h \
IBResourceManager.h \
IBSystem.h \
IBViewAdditions.h \
IBViewProtocol.h \
IBViewResourceDragging.h \
InterfaceBuilder.h

#
# Class files
#

InterfaceBuilder_OBJC_FILES= \
IBApplicationAdditions.m \
IBConnectors.m \
IBDocuments.m \
IBEditors.m \
IBInspector.m \
IBInspectorManager.m \
IBInspectorMode.m \
IBObjectAdditions.m \
IBPalette.m \
IBPlugin.m \
IBResourceManager.m

#
# C files
#

InterfaceBuilder_C_FILES= 

HEADERS_INSTALL = $(InterfaceBuilder_HEADER_FILES)

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble
