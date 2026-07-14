include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = HTTPServer

NEEDS_GUI=NO

HTTPServer_OBJC_FILES = HTTPServer.m
HTTPServer_OBJC_LIBS += -ldispatch

ifeq ($(GNUSTEP_TARGET_OS), windows)
HTTPServer_OBJC_LIBS += -lws2_32
endif

HTTPServer_OBJCFLAGS += -fobjc-arc
#HTTPServer_RESOURCE_FILES += key.pem certificate.pem
HTTPServer_PRINCIPAL_CLASS = HTTPServer

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
