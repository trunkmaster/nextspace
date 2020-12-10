#ifndef __WORKSPACE_WM_WUSERDEFAULTS__
#define __WORKSPACE_WM_WUSERDEFAULTS__

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPropertyList.h>
/* #include <CoreFoundation/CFString.h> */
/* #include <CoreFoundation/CFDictionary.h> */
/* #include <CoreFoundation/CFArray.h> */

/* Paths */
CFStringRef WMUserName();
CFStringRef WMHomePathForUser(CFStringRef username);
CFStringRef WMUserLibraryPath();
CFStringRef WMPathForDefaultsDomain(CFStringRef domain);

/* Property List */
CFPropertyListRef WMObjectFromDescription(const char *description);
CFPropertyListRef WMUserDefaultsReadFromFile(CFStringRef path);

#endif
