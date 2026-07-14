#
# GNUmakefile -- gormtool
#

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = gormtool
TOOL_NAME = gormtool

gormtool_HEADER_FILES = AppDelegate.h \
	GormToolPrivate.h \
	ArgPair.h

gormtool_OBJC_FILES = main.m \
	AppDelegate.m \
	GormToolPrivate.m \
	ArgPair.m

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/tool.make

-include GNUmakefile.postamble
