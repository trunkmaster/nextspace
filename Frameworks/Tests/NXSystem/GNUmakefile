
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME=ScreenInfo
$(TOOL_NAME)_OBJC_FILES=$(wildcard *.m)

$(TOOL_NAME)_STANDARD_INSTALL=no

ADDITIONAL_LDFLAGS += -lNXSystem -lNXFoundation

-include GNUmakefile.platform
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
