#ifndef __WORKSPACE_WM_WUSERDEFAULTS__
#define __WORKSPACE_WM_WUSERDEFAULTS__

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPropertyList.h>
/* #include <CoreFoundation/CFString.h> */
/* #include <CoreFoundation/CFDictionary.h> */
/* #include <CoreFoundation/CFArray.h> */

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
void WMUserDefaultsMerge(CFMutableDictionaryRef dest, CFDictionaryRef source);

#endif
