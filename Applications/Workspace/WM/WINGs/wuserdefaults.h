#ifndef __WORKSPACE_WM_WUSERDEFAULTS__
#define __WORKSPACE_WM_WUSERDEFAULTS__

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPropertyList.h>
/* #include <CoreFoundation/CFString.h> */
/* #include <CoreFoundation/CFDictionary.h> */
/* #include <CoreFoundation/CFArray.h> */

/* Paths */
CFURLRef WMUserDefaultsCopyURLForDomain(CFStringRef domain);
CFStringRef WMUserDefaultsCopyPathForDomain(CFStringRef domain);

/* Property List */
CFPropertyListRef WMUserDefaultsFromDescription(const char *description);
CFPropertyListRef WMUserDefaultsFromFile(CFURLRef pathURL);
CFAbsoluteTime WMUserDefaultsFileModificationTime(CFURLRef pathURL);

#endif
