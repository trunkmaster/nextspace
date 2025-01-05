# -*- mode: makefile-gmake -*-

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = SystemKit
FRAMEWORK_NAME = SystemKit
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
	SystemKit.h\
	OSESystemInfo.h\
	\
	OSEDefaults.h \
	OSEFileManager.h \
	OSEFileSystem.h \
	OSEFileSystemMonitor.h \
	\
	OSEScreen.h \
	OSEDisplay.h \
	\
	OSEBusConnection.h \
	OSEBusMessage.h \
	OSEBusService.h \
	\
	OSEDeviceManager.h \
	OSEMediaManager.h \
	OSEUDisksAdaptor.h \
	OSEUDisksDrive.h \
	OSEUDisksVolume.h \
	\
	OSEKeyboard.h \
	OSEMouse.h \
	\
	OSEPower.h

$(FRAMEWORK_NAME)_RESOURCE_FILES = 

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
-include GNUmakefile.postamble
