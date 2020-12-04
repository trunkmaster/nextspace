#include <CoreFoundation/CoreFoundation.h>

CFStringRef WMUserName();
CFStringRef WMHomePathForUser(CFStringRef username);
CFStringRef WMUserLibraryPath();
CFStringRef WMPathForDefaultsDomain(CFStringRef domain);
