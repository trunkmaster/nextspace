#
# GNUmakefile for BusKit framework
#

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

include $(GNUSTEP_MAKEFILES)/common.make

# Framework
PACKAGE_NAME = BusKit
FRAMEWORK_NAME = BusKit
VERSION = 0.1
$(FRAMEWORK_NAME)_CURRENT_VERSION_NAME = $(VERSION)
$(FRAMEWORK_NAME)_DEPLOY_WITH_CURRENT_VERSION = yes

$(FRAMEWORK_NAME)_OBJC_FILES = $(wildcard *.m)
$(FRAMEWORK_NAME)_HEADER_FILES = $(wildcard *.h)
$(FRAMEWORK_NAME)_LDFLAGS = -lgnustep-base `pkg-config dbus-1 --libs`

# ADDITIONAL_LIB_DIRS += -L
ADDITIONAL_OBJCFLAGS += -Wall -Wno-deprecated-declarations `pkg-config dbus-1 --cflags`

# Makefiles
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
