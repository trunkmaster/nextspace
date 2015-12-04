
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME=FileMover.tool
$(TOOL_NAME)_OBJC_FILES=$(wildcard *.m) ../Communicator.m
$(TOOL_NAME)_C_FILES=$(wildcard *.c)

$(TOOL_NAME)_STANDARD_INSTALL=no

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
