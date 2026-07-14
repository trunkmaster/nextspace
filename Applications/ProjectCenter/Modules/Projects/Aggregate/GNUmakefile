#
# GNUmakefile - Aggregate.project
#
PACKAGE_NAME = ProjectCenter
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = Aggregate
BUNDLE_EXTENSION = .project
Aggregate_PRINCIPAL_CLASS = PCAggregateProject

#
# Additional libraries
#
Aggregate_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
Aggregate_RESOURCE_FILES= \
    Resources/PC.project \
    Resources/Inspector.gorm \
    Resources/Info.table

#
# Header files
#
Aggregate_HEADERS= \
    PCAggregateProject.h 

#
# Class files
#
Aggregate_OBJC_FILES= \
    PCAggregateProject.m 

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make
