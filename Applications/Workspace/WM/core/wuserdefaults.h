/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef __WORKSPACE_WM_WUSERDEFAULTS__
#define __WORKSPACE_WM_WUSERDEFAULTS__

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPropertyList.h>

/* Files */
CFURLRef WMUserDefaultsCopyUserLibraryURL(void);
CFURLRef WMUserDefaultsCopyURLForDomain(CFStringRef domain);
CFStringRef WMUserDefaultsCopyPathForDomain(CFStringRef domain);
CFURLRef WMUserDefaultsCopySystemURLForDomain(CFStringRef domain);

/* Property List */
CFPropertyListRef WMUserDefaultsFromDescription(const char *description);
char *WMUserDefaultsGetCString(CFStringRef string, CFStringEncoding encoding);

CFPropertyListFormat WMUserDefaultsFileExists(CFStringRef domainName,
                                              CFPropertyListFormat format);
CFAbsoluteTime WMUserDefaultsFileModificationTime(CFStringRef domainName,
                                                  CFPropertyListFormat format);

CFPropertyListRef WMUserDefaultsReadFromFile(CFURLRef fileURL);
/* CFPropertyListRef WMUserDefaultsRead(CFStringRef domainName); */
CFPropertyListRef WMUserDefaultsRead(CFStringRef domainName, Boolean useSystemDomain);
Boolean WMUserDefaultsWrite(CFTypeRef dictionary, CFStringRef domainName);
void WMUserDefaultsMerge(CFMutableDictionaryRef dest, CFDictionaryRef source);

#endif /* __WORKSPACE_WM_WUSERDEFAULTS__ */
