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
	SKSoundServer.m \
	SKSoundServerCallbacks.m \
	SKSoundDevice.m \
	SKSoundOut.m \
	SKSoundIn.m \
	SKSoundStream.m \
	SKSoundVirtualStream.m
endif

$(FRAMEWORK_NAME)_HEADER_FILES = \
	SoundKit.h \
	SKSoundServer.h \
	SKSoundDevice.h \
	SKSoundOut.h \
	SKSoundIn.h \
	SKSoundStream.h \
	SKSoundVirtualStream.h

$(FRAMEWORK_NAME)_RESOURCE_FILES = 

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
-include GNUmakefile.postamble
