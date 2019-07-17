#
# GNUmakefile for SoundKit framework
#

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = SoundKit
FRAMEWORK_NAME = SoundKit
VERSION = 0.1
$(FRAMEWORK_NAME)_CURRENT_VERSION_NAME = 0.1
$(FRAMEWORK_NAME)_DEPLOY_WITH_CURRENT_VERSION = yes

# FreeBSD
# ifeq ($(findstring freebsd, $(GNUSTEP_TARGET_OS)), freebsd)
#   $(FRAMEWORK_NAME)_OBJC_FILES += $(wildcard FreeBSD/*.m)
# endif

# Linux
ifeq ($(findstring gnu, $(GNUSTEP_TARGET_OS)), gnu)
  $(FRAMEWORK_NAME)_OBJC_FILES += \
	PACard.m \
	PASink.m \
	PASource.m \
	\
	PASinkInput.m \
	PASourceOutput.m \
	PAClient.m \
	PAStream.m \
	\
	SNDServer.m \
	SNDServerCallbacks.m \
	SNDDevice.m \
	SNDOut.m \
	SNDIn.m \
	SNDStream.m \
	SNDPlayStream.m \
	SNDRecordStream.m \
	SNDVirtualStream.m \
	\
	NXTSound.m
endif

$(FRAMEWORK_NAME)_HEADER_FILES = \
	SoundKit.h \
	SNDServer.h \
	SNDDevice.h \
	SNDOut.h \
	SNDIn.h \
	SNDStream.h \
	SNDPlayStream.h \
	SNDRecordStream.h \
	SNDVirtualStream.h \
	\
	NXTSound.h

$(FRAMEWORK_NAME)_RESOURCE_FILES = 

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
-include GNUmakefile.postamble
