# -*- mode: makefile-gmake -*-

include $(GNUSTEP_MAKEFILES)/common.make

#TOOL_NAME = dbk_test libnm_test
TOOL_NAME = dbk_test

dbk_test_OBJC_FILES = dbk_test.m
dbk_test_TOOL_LIBS = -lDBusKit `pkg-config dbus-1 --libs`

#libnm_test_OBJC_FILES = libnm_test.m
#libnm_test_TOOL_LIBS = `pkg-config --libs libnm`
#libnm_test_OBJCFLAGS += `pkg-config --cflags libnm`

#ADDITIONAL_TOOL_LIBS = -lDBusKit `pkg-config dbus-1 --libs` `pkg-config --libs libnm`
ADDITIONAL_OBJCFLAGS += -Wall -Wno-deprecated-declarations -I ../

# Makefiles
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
