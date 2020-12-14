#ifndef __WORKSPACE_WM_WUSERDEFAULTS__
#define __WORKSPACE_WM_WUSERDEFAULTS__

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPropertyList.h>
#include <CoreFoundation/CFLogUtilities.h>

#include "defaults.h"

/* Files */
CFURLRef WMUserDefaultsCopyUserLibraryURL(void);
CFURLRef WMUserDefaultsCopyURLForDomain(CFStringRef domain);
CFStringRef WMUserDefaultsCopyPathForDomain(CFStringRef domain);

/* Property List */
CFPropertyListRef WMUserDefaultsFromDescription(const char *description);
char *WMUserDefaultsGetCString(CFStringRef string, CFStringEncoding encoding);

CFPropertyListFormat WMUserDefaultsFileExists(CFStringRef domainName,
                                              CFPropertyListFormat format);
CFAbsoluteTime WMUserDefaultsFileModificationTime(CFStringRef domainName,
                                                  CFPropertyListFormat format);

CFPropertyListRef WMUserDefaultsRead(CFStringRef domainName);
Boolean WMUserDefaultsWrite(CFDictionaryRef dictionary, CFStringRef domainName);
Boolean WMUserDefaultsSynchronize(WDDomain *domain);
void WMUserDefaultsMerge(CFMutableDictionaryRef dest, CFDictionaryRef source);

#endif
