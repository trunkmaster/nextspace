#ifndef __WORKSPACE_WM_WUTIL__
#define __WORKSPACE_WM_WUTIL__

#include <CoreFoundation/CoreFoundation.h>

CFStringRef WMUserName();
CFStringRef WMHomePathForUser(CFStringRef username);
CFStringRef WMUserLibraryPath();
CFStringRef WMPathForDefaultsDomain(CFStringRef domain);

#endif
