#
# GNUmakefile for NXSystem framework - OS specific code
#
# It aims to the only place for platform dependant code in CUBE.
# OS-dependant calls. Abstraction layer to hide OS specifics.
#

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = NXSystem
FRAMEWORK_NAME = NXSystem
VERSION = 0.3
$(FRAMEWORK_NAME)_CURRENT_VERSION_NAME = 0.3
$(FRAMEWORK_NAME)_DEPLOY_WITH_CURRENT_VERSION = yes

# Abstract classes
$(FRAMEWORK_NAME)_OBJC_FILES = $(wildcard *.m)

# OS specific code
# FreeBSD
ifeq ($(findstring freebsd, $(GNUSTEP_TARGET_OS)), freebsd)
  $(FRAMEWORK_NAME)_OBJC_FILES += $(wildcard FreeBSD/*.m)
endif

# Linux
ifeq ($(findstring gnu, $(GNUSTEP_TARGET_OS)), gnu)
  $(FRAMEWORK_NAME)_OBJC_FILES += $(wildcard Linux/*.m)
endif

$(FRAMEWORK_NAME)_HEADER_FILES = \
	NXSystem.h\
	NXSystemInfo.h\
	\
	NXFileSystem.h \
	NXFileSystemMonitor.h \
	\
	NXScreen.h \
	NXDisplay.h \
	\
	NXDeviceManager.h \
	NXMediaManager.h \
	NXUDisksAdaptor.h \
	NXUDisksDrive.h \
	NXUDisksVolume.h \
	\
	NXPower.h

$(FRAMEWORK_NAME)_RESOURCE_FILES = 

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
-include GNUmakefile.postamble
