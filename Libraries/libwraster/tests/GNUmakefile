
include $(GNUSTEP_MAKEFILES)/common.make

CTOOL_NAME=view
$(CTOOL_NAME)_C_FILES=view.c

$(CTOOL_NAME)_STANDARD_INSTALL=no

ADDITIONAL_TOOL_LIBS = -lwraster -lX11

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/ctool.make
-include GNUmakefile.postamble
