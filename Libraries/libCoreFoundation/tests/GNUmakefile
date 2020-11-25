#
# GNUmakefile
#

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM
include $(GNUSTEP_MAKEFILES)/common.make

CTOOL_NAME = proplist_test notification_test runloop_test

proplist_test_C_FILES = proplist_test.c
notification_test_C_FILES = notification_test.c
runloop_test_C_FILES = runloop_test.c

#
# GNUmakefile.preamble
#

# Additional flags to pass to the preprocessor
ADDITIONAL_CPPFLAGS += 
# Additional flags to pass to Objective C compiler
ADDITIONAL_OBJCFLAGS += -fblocks
# Additional flags to pass to C compiler
ADDITIONAL_CFLAGS += -Wall -fblocks
# Additional flags to pass to the linker
ADDITIONAL_LDFLAGS = -lCoreFoundation -lX11
# Additional include directories the compiler should search
ADDITIONAL_INCLUDE_DIRS +=
# Additional library directories the linker should search
ADDITIONAL_LIB_DIRS += 


#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/ctool.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
