
#include "WINGsP.h"
#include "wconfig.h"

#include <X11/Xlocale.h>

_WINGsConfiguration WINGsConfiguration;

#define SYSTEM_FONT "sans serif"
#define BOLD_SYSTEM_FONT "sans serif:bold"
#define DEFAULT_FONT_SIZE 12

#define FLOPPY_PATH "/floppy"

static unsigned getButtonWithName(const char *name, unsigned defaultButton)
{
	if (strncmp(name, "Button", 6) == 0 && strlen(name) == 7) {
		switch (name[6]) {
		case '1':
			return Button1;
		case '2':
			return Button2;
		case '3':
			return Button3;
		case '4':
			return Button4;
		case '5':
			return Button5;
		default:
			break;
		}
	}

	return defaultButton;
}

void W_ReadConfigurations(void)
{
	WMUserDefaults *defaults;
	Bool aaIsSet = False;

	memset(&WINGsConfiguration, 0, sizeof(_WINGsConfiguration));

	defaults = WMGetStandardUserDefaults();

	if (defaults) {
		char *buttonName;
		WMPropList *val;
		unsigned button;

		WINGsConfiguration.systemFont = WMGetUDStringForKey(defaults, "SystemFont");

		WINGsConfiguration.boldSystemFont = WMGetUDStringForKey(defaults, "BoldSystemFont");

		val = WMGetUDObjectForKey(defaults, "AntialiasedText");
		if (val && WMIsPLString(val) && WMGetFromPLString(val)) {
			aaIsSet = True;
			WINGsConfiguration.antialiasedText =
				WMGetUDBoolForKey(defaults, "AntialiasedText");
		}

		WINGsConfiguration.doubleClickDelay = WMGetUDIntegerForKey(defaults, "DoubleClickTime");

		WINGsConfiguration.floppyPath = WMGetUDStringForKey(defaults, "FloppyPath");

		buttonName = WMGetUDStringForKey(defaults, "MouseWheelUp");
		if (buttonName) {
			button = getButtonWithName(buttonName, Button4);
			wfree(buttonName);
		} else {
			button = Button4;
		}
		WINGsConfiguration.mouseWheelUp = button;

		buttonName = WMGetUDStringForKey(defaults, "MouseWheelDown");
		if (buttonName) {
			button = getButtonWithName(buttonName, Button5);
			wfree(buttonName);
		} else {
			button = Button5;
		}
		WINGsConfiguration.mouseWheelDown = button;

		if (WINGsConfiguration.mouseWheelDown == WINGsConfiguration.mouseWheelUp) {
			WINGsConfiguration.mouseWheelUp = Button4;
			WINGsConfiguration.mouseWheelDown = Button5;
		}

		WINGsConfiguration.defaultFontSize = WMGetUDIntegerForKey(defaults, "DefaultFontSize");
	}

	if (!WINGsConfiguration.systemFont) {
		WINGsConfiguration.systemFont = SYSTEM_FONT;
	}
	if (!WINGsConfiguration.boldSystemFont) {
		WINGsConfiguration.boldSystemFont = BOLD_SYSTEM_FONT;
	}
	if (WINGsConfiguration.defaultFontSize == 0) {
		WINGsConfiguration.defaultFontSize = DEFAULT_FONT_SIZE;
	}
	if (!aaIsSet) {
		WINGsConfiguration.antialiasedText = True;
	}
	if (!WINGsConfiguration.floppyPath) {
		WINGsConfiguration.floppyPath = FLOPPY_PATH;
	}
	if (WINGsConfiguration.doubleClickDelay == 0) {
		WINGsConfiguration.doubleClickDelay = 250;
	}
	if (WINGsConfiguration.mouseWheelUp == 0) {
		WINGsConfiguration.mouseWheelUp = Button4;
	}
	if (WINGsConfiguration.mouseWheelDown == 0) {
		WINGsConfiguration.mouseWheelDown = Button5;
	}

}

unsigned W_getconf_mouseWheelUp(void)
{
	return WINGsConfiguration.mouseWheelUp;
}

unsigned W_getconf_mouseWheelDown(void)
{
	return WINGsConfiguration.mouseWheelDown;
}

void W_setconf_doubleClickDelay(int value)
{
	WINGsConfiguration.doubleClickDelay = value;
}
