#ifndef __WORKSPACE_WM_WUSERDEFAULTS__
#define __WORKSPACE_WM_WUSERDEFAULTS__

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPropertyList.h>
/* #include <CoreFoundation/CFString.h> */
/* #include <CoreFoundation/CFDictionary.h> */
/* #include <CoreFoundation/CFArray.h> */
#include <CoreFoundation/CFLogUtilities.h>

#include "defaults.h"

/* Paths */
CFURLRef WMUserDefaultsCopyUserLibraryURL(void);
CFURLRef WMUserDefaultsCopyURLForDomain(CFStringRef domain);
CFStringRef WMUserDefaultsCopyPathForDomain(CFStringRef domain);

/* Property List */
CFPropertyListRef WMUserDefaultsFromDescription(const char *description);
char *WMUserDefaultsGetCString(CFStringRef string, CFStringEncoding encoding);

CFAbsoluteTime WMUserDefaultsFileModificationTime(CFURLRef pathURL);

CFPropertyListRef WMUserDefaultsRead(CFURLRef pathURL);
Boolean WMUserDefaultsWrite(CFDictionaryRef dictionary, CFURLRef fileURL);
Boolean WMUserDefaultsUpdateDomain(WDDomain *domain);
void WMUserDefaultsMerge(CFMutableDictionaryRef dest, CFDictionaryRef source);

#endif
