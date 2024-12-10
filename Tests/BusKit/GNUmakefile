#
# GNUmakefile for BusKit tools
#

include $(GNUSTEP_MAKEFILES)/common.make

# Testing tool
TOOL_NAME = dbus_talk
$(TOOL_NAME)_STANDARD_INSTALL = no
$(TOOL_NAME)_OBJC_FILES = $(wildcard *.m)
$(TOOL_NAME)_LDFLAGS += -lgnustep-base `pkg-config dbus-1 --libs` -lBusKit -lDBusKit

# ADDITIONAL_LIB_DIRS += -L
ADDITIONAL_OBJCFLAGS += -Wall -Wno-deprecated-declarations `pkg-config dbus-1 --cflags`

# Makefiles
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
