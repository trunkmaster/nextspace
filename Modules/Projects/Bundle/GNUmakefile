#
# GNUmakefile - BundleProject
#
PACKAGE_NAME = ProjectCenter
include $(GNUSTEP_MAKEFILES)/common.make

#
# Bundle
#
BUNDLE_NAME = Bundle
BUNDLE_EXTENSION = .project
Bundle_PRINCIPAL_CLASS = PCBundleProject


#
# Additional libraries
#
Bundle_LIBRARIES_DEPEND_UPON +=

#
# Resource files
#
Bundle_RESOURCE_FILES = \
  Resources/PC.project \
  Resources/Inspector.gorm \
  Resources/Info.table

#
# Header files
#
Bundle_HEADERS = \
  PCBundleProject.h

#
# Class files
#

Bundle_OBJC_FILES= \
  PCBundleProject.m

include ../../GNUmakefile.bundles
include $(GNUSTEP_MAKEFILES)/bundle.make
