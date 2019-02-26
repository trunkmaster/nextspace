include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = displaytool

$(TOOL_NAME)_STANDARD_INSTALL = yes

$(TOOL_NAME)_OBJC_FILES = displaytool_main.m

$(TOOL_NAME)_NEEDS_GUI = yes

ADDITIONAL_INCLUDE_DIRS += `pkg-config --cflags upower-glib`
ADDITIONAL_OBJCFLAGS += -DWITH_UPOWER
ADDITIONAL_LDFLAGS += -lNXSystem -lNXFoundation

include $(GNUSTEP_MAKEFILES)/tool.make
include $(GNUSTEP_MAKEFILES)/ctool.make
