#
#  GNUmakefile
#

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = Workspace
VERSION = 0.8
REVISION = "`git log -n 1 --date=short --format=format:"%h, %ad"`"
APP_NAME = Workspace
OS_NAME=`./os-release`
$(APP_NAME)_APPLICATION_ICON = App-$(OS_NAME)-48.tiff
$(APP_NAME)_MAIN_MODEL_FILE = WorkspaceManager

SUBPROJECTS = \
	Viewers/BrowserViewer \
	Viewers/IconViewer \
	Inspectors \
	Tools/FileMover \
	Tools/Sizer \
	Preferences/Advanced \
	Preferences/Browser \
	Preferences/Dock \
	Preferences/FileCopyOptions \
	Preferences/IconView \
	Preferences/Shelf \
	Preferences/Workspaces

$(APP_NAME)_OBJC_FILES = \
	$(wildcard *.m) \
	$(wildcard Viewers/*.m) \
	$(wildcard Operations/*.m) \
	$(wildcard Processes/*.m)

$(APP_NAME)_RESOURCE_FILES = \
	$(wildcard Resources/*) \
	Inspectors/Inspectors.bundle \
	$(wildcard Processes/English.lproj)

# Window manager
WM_DIR = WM
include GNUmakefile.WM

$(APP_NAME)_LOCALIZED_RESOURCE_FILES = $(notdir $(wildcard English.lproj/*))

$(APP_NAME)_LANGUAGES = $(basename $(wildcard *.lproj))

$(APP_NAME)_HEADER_FILES = Inspectors/Workspace.h
$(APP_NAME)_HEADER_FILES_INSTALL_DIR = $(GNUSTEP_SYSTEM_HEADERS)/Applications

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
include $(GNUSTEP_MAKEFILES)/Instance/Shared/headers.make
-include GNUmakefile.postamble
