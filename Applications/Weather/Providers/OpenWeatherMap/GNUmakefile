include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = OpenWeatherMap
BUNDLE_EXTENSION = .forecast

$(BUNDLE_NAME)_PRINCIPAL_CLASS = OWMForecast
$(BUNDLE_NAME)_STANDARD_INSTALL = no

$(BUNDLE_NAME)_OBJC_FILES= \
	OWMForecast.m

$(BUNDLE_NAME)_RESOURCE_FILES = \
	$(wildcard Resources/*.png) \
	Resources/bundle.registry

#$(BUNDLE_NAME)_LANGUAGES = English
#$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES= Display.gorm

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
