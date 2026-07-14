#
# GNUmakefile - ProjectCenter.editor
#
PACKAGE_NAME = ProjectCenter
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = ProjectCenter
BUNDLE_EXTENSION = .editor
ProjectCenter_PRINCIPAL_CLASS = PCEditor

#
# Additional libraries
#
ProjectCenter_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
ProjectCenter_RESOURCE_FILES= \
    Resources/Info.table \
    Resources/C.syntax \
    Resources/ObjC.syntax \
    Resources/Plist.syntax \
    Resources/FileC.tiff \
    Resources/FileCH.tiff \
    Resources/FileH.tiff \
    Resources/FileHH.tiff \
    Resources/FileM.tiff \
    Resources/FileMH.tiff \
    Resources/FileMM.tiff \
    Resources/LineJumper.gorm

#
# Header files
#
ProjectCenter_HEADERS= \
    PCEditor.h \
    PCEditorView.h \
    SyntaxDefinition.h \
    SyntaxHighlighter.h \
    LineJumper.h

#
# Class files
#
ProjectCenter_OBJC_FILES= \
    PCEditor.m \
    PCEditorView.m \
    TextPattern.m \
    SyntaxDefinition.m \
    SyntaxHighlighter.m \
    LineJumper.m

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make
