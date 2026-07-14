#
# GNUmakefile 
# Written by Gregory John Casamento <greg_casamento@yahoo.com>
#
PACKAGE_NAME = gorm
include $(GNUSTEP_MAKEFILES)/common.make

#
# Subprojects
#
SUBPROJECTS = \
Tests

#
# Library
#
LIBRARY_VAR=GMOBJCHEADERPARSER
LIBRARY_NAME=GormObjCHeaderParser
GormObjCHeaderParser_HEADER_FILES_DIR=.
ADDITIONAL_INCLUDE_DIRS = -I..

#
# Additional libraries
#
GormObjCHeaderParser_LIBRARIES_DEPEND_UPON += -lgnustep-gui -l$(FOUNDATION_LIBRARY_NAME)

#
# Header files
#
GormObjCHeaderParser_HEADER_FILES= \
GormObjCHeaderParser.h \
NSScanner+OCHeaderParser.h \
OCClass.h \
OCHeaderParser.h \
OCIVar.h \
OCIVarDecl.h \
OCMethod.h \
OCProperty.h \
ParserFunctions.h

#
# Class files
#
GormObjCHeaderParser_OBJC_FILES= \
NSScanner+OCHeaderParser.m \
OCClass.m \
OCHeaderParser.m \
OCIVar.m \
OCIVarDecl.m \
OCMethod.m \
OCProperty.m \
ParserFunctions.m

#
# C files
#
GormObjCHeaderParser_C_FILES= 

HEADERS_INSTALL = $(GormObjCHeaderParser_HEADER_FILES)

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble
