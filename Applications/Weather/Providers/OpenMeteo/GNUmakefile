include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = OpenMeteo
BUNDLE_EXTENSION = .provider

$(BUNDLE_NAME)_PRINCIPAL_CLASS = OpenMeteo
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_OBJC_FILES= \
	OpenMeteo.m \
	../WeatherProvider.m

$(BUNDLE_NAME)_RESOURCE_FILES = \
	$(wildcard Resources/*.png) \
	Resources/bundle.registry

#$(BUNDLE_NAME)_LANGUAGES = English
#$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES =

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
