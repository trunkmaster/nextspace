include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = disktool

$(TOOL_NAME)_STANDARD_INSTALL=yes

$(TOOL_NAME)_OBJC_FILES = disktool_main.m

$(TOOL_NAME)_NEEDS_GUI = no

#ADDITIONAL_INCLUDE_DIRS += `pkg-config --cflags udisks2` `pkg-config --cflags dbus-1`
#ADDITIONAL_OBJCFLAGS += -DWITH_UDISKS
ADDITIONAL_LDFLAGS += -lNXSystem -lNXFoundation

include $(GNUSTEP_MAKEFILES)/tool.make
include $(GNUSTEP_MAKEFILES)/ctool.make
