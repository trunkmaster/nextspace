include $(GNUSTEP_MAKEFILES)/common.make
TOOL_NAME = unicode-view-test
unicode-view-test_OBJC_FILES = unicode-view-test.m ../../TerminalView.m ../../TerminalGlyphRenderer.m ../../TerminalParser_Ghostty.m ../../TerminalParser_Linux.m ../../Defaults.m
ADDITIONAL_INCLUDE_DIRS += -I../..
ADDITIONAL_OBJCFLAGS += -DUSE_GHOSTTY_VT=1 $(shell pkg-config --cflags freetype2 fontconfig harfbuzz)
ADDITIONAL_TOOL_LIBS += -lgnustep-gui -lghostty-vt -liconv -lDesktopKit -lSystemKit -lX11 -ldispatch -lutil -lfreetype -lfontconfig -lharfbuzz
include $(GNUSTEP_MAKEFILES)/tool.make
