include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = sysinfo

$(TOOL_NAME)_STANDARD_INSTALL=no

$(TOOL_NAME)_OBJC_FILES = sysinfo.m

$(TOOL_NAME)_NEEDS_GUI = yes

#ADDITIONAL_INCLUDE_DIRS += `pkg-config --cflags udisks2` `pkg-config --cflags dbus-1`
#ADDITIONAL_OBJCFLAGS +=
ADDITIONAL_LDFLAGS += -lSystemKit -lDesktopKit

include $(GNUSTEP_MAKEFILES)/tool.make
include $(GNUSTEP_MAKEFILES)/ctool.make
