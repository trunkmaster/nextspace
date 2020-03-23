# -*- mode: makefile-gmake -*-

include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = dbk_test
$(TOOL_NAME)_OBJC_FILES = dbk_test.m

#ADDITIONAL_LIB_DIRS += -L
ADDITIONAL_TOOL_LIBS = -lDBusKit `pkg-config dbus-1 --libs`
ADDITIONAL_OBJCFLAGS += -Wall -Wno-deprecated-declarations -I ../

# Makefiles
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
