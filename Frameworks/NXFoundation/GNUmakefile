#
# NXFoundation framework GNUmakefile
#
GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = NXFoundation
FRAMEWORK_NAME = NXFoundation
VERSION = 0.3
$(FRAMEWORK_NAME)_CURRENT_VERSION_NAME = 0.3
$(FRAMEWORK_NAME)_DEPLOY_WITH_CURRENT_VERSION = yes
#$(FRAMEWORK_NAME)_HEADER_FILES_DIR = ./
#$(FRAMEWORK_NAME)_LIBRARIES_DEPEND_UPON += $(OBJC_LIBS) $(FND_LIBS) $(GUI_LIBS)

$(FRAMEWORK_NAME)_OBJC_FILES = \
	NXBundle.m \
	NXDefaults.m \
	NXFileManager.m

$(FRAMEWORK_NAME)_HEADER_FILES = \
	NXBundle.h \
	NXDefaults.h \
	NXFileManager.h

$(FRAMEWORK_NAME)_RESOURCE_FILES = 

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
-include GNUmakefile.postamble
