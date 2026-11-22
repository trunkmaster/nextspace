#
include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = nextspace-applications
VERSION = 0.95
SUBPROJECTS = \
	Login \
	Workspace \
	Preferences \
	Terminal \
	TextEdit \
	TimeMon \
	Review \
	OpenUp \
	Sleep

# apm-backed dock monitor is available on FreeBSD.
ifneq (,$(findstring freebsd,$(GNUSTEP_TARGET_OS)))
SUBPROJECTS += Battery
endif

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble

