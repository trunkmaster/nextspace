#ifndef __WORKSPACE_WM_WUSERDEFAULTS__
#define __WORKSPACE_WM_WUSERDEFAULTS__

#include <CoreFoundation/CoreFoundation.h>

CFStringRef WMUserName();
CFStringRef WMHomePathForUser(CFStringRef username);
CFStringRef WMUserLibraryPath();
CFStringRef WMPathForDefaultsDomain(CFStringRef domain);

#endif
