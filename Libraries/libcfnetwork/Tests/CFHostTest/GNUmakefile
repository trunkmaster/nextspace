include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = gethostbyname

$(TOOL_NAME)_STANDARD_INSTALL = no

$(TOOL_NAME)_C_FILES = gethostbyname.c

$(TOOL_NAME)_NEEDS_GUI = no

ADDITIONAL_CFLAGS += -F/usr/NextSpace/Frameworks
ADDITIONAL_LDFLAGS += -lCoreFoundation -lCFNetwork

include $(GNUSTEP_MAKEFILES)/tool.make
include $(GNUSTEP_MAKEFILES)/ctool.make
