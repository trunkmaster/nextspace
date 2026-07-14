#
# GNUmakefile - Aggregate.project
#
PACKAGE_NAME = ProjectCenter
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = ResourceSet
BUNDLE_EXTENSION = .project
ResourceSet_PRINCIPAL_CLASS = PCResourceSetProject

#
# Additional libraries
#
ResourceSet_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
ResourceSet_RESOURCE_FILES= \
    Resources/PC.project \
    Resources/Inspector.gorm \
    Resources/Info.table

#
# Header files
#
ResourceSet_HEADERS= \
    PCResourceSetProject.h 

#
# Class files
#
ResourceSet_OBJC_FILES= \
    PCResourceSetProject.m 

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make
