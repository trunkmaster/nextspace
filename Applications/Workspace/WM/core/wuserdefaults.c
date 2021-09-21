/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
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

#include "log_utils.h"
#include "file_utils.h"
#include "defaults.h"
#include "wuserdefaults.h"

// ---[ Location ] --------------------------------------------------------------------------------

// /Users/$USER/Library
#define USER_LIBRARY_DIR "Library"
// $USER_LIBRARY_DIR/Preferences/.NextSpace
#define DEFAULTS_SUBDIR "Preferences/.NextSpace"

CFURLRef WMUserDefaultsCopyUserLibraryURL(void)
{
  CFURLRef homePath = CFCopyHomeDirectoryURL();
  CFURLRef libPath;

  libPath = CFURLCreateCopyAppendingPathComponent(NULL, homePath, CFSTR(USER_LIBRARY_DIR), true);
  CFRelease(homePath);

  return libPath;
}

CFURLRef WMUserDefaultsCopyURLForDomain(CFStringRef domain)
{
  CFURLRef libURL, prefsURL;
  CFURLRef domainURL;
  
  libURL = WMUserDefaultsCopyUserLibraryURL();
  prefsURL = CFURLCreateCopyAppendingPathComponent(NULL, libURL, CFSTR(DEFAULTS_SUBDIR), true);
  CFRelease(libURL);
  
  if (CFStringGetLength(domain) > 0) {
    domainURL = CFURLCreateCopyAppendingPathComponent(NULL, prefsURL, domain, false);
  }
  else {
    CFRetain(prefsURL);
    domainURL = prefsURL;
  }

  CFRelease(prefsURL);
  
  return domainURL;
}

CFStringRef WMUserDefaultsCopyStringForDomain(CFStringRef domain)
{
  CFURLRef url;
  CFStringRef stringURL;
  UInt8 *buffer;

  url = WMUserDefaultsCopyURLForDomain(domain);
  buffer = malloc(sizeof(UInt8) * MAXPATHLEN);
  CFURLGetFileSystemRepresentation(url, false, buffer, MAXPATHLEN);
  CFRelease(url);
  stringURL = CFStringCreateWithCString(kCFAllocatorDefault, (const char *)buffer,
                                        kCFStringEncodingUTF8);
  free(buffer);

  return stringURL;
}

// /usr/NextSpace/Apps/Workspace.app/Resources/<domain>.plist
CFURLRef WMUserDefaultsCopySystemURLForDomain(CFStringRef domain)
{
  CFURLRef sysdefsURL;
  CFURLRef domainURL;
  CFStringRef domainFileName;

  domainFileName = CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%@.plist"), domain);
  
  sysdefsURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR(SYSTEM_DEFAULTS_DIR),
                                             kCFURLPOSIXPathStyle, true);
  
  if (CFStringGetLength(domain) > 0) {
    domainURL = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, sysdefsURL,
                                                      domainFileName, false);
  }
  else {
    CFRetain(sysdefsURL);
    domainURL = sysdefsURL;
  }

  CFRelease(sysdefsURL);
  CFRelease(domainFileName);

  return domainURL;
}

// ---[ Dictionary ] ------------------------------------------------------------------------------
CFPropertyListRef WMUserDefaultsFromDescription(const char *description)
{
  const UInt8          *desc = (const UInt8 *)description;
  CFDataRef            data;
  CFPropertyListFormat plFormat = kCFPropertyListOpenStepFormat;
  CFErrorRef           plError = NULL;

  data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, desc, strlen(description),
                                     kCFAllocatorNull);
  return CFPropertyListCreateWithData(kCFAllocatorDefault, data, 0, &plFormat, &plError);
}

char *WMUserDefaultsGetCString(CFStringRef string, CFStringEncoding encoding)
{
  CFIndex length = CFStringGetLength(string) + 1;
  char    *buffer = NULL;

  buffer = (char *)malloc(sizeof(char) * length);
  CFStringGetCString(string, buffer, length, encoding);

  return buffer;
}

// ---[ Files ] -----------------------------------------------------------------------------------
CFPropertyListFormat WMUserDefaultsFileExists(CFStringRef domainName,
                                              CFPropertyListFormat format)
{
  CFURLRef osURL = NULL;
  CFURLRef xmlURL = NULL;
  int error;
  CFBooleanRef pathExists = false;
  CFPropertyListFormat result = 0;
  
  osURL = WMUserDefaultsCopyURLForDomain(domainName);
  
  if (format == 0 || format == kCFPropertyListXMLFormat_v1_0) {
    xmlURL = CFURLCreateCopyAppendingPathExtension(kCFAllocatorDefault, osURL, CFSTR("plist"));
    pathExists = CFURLCreatePropertyFromResource(kCFAllocatorDefault, xmlURL,
                                                 kCFURLFileExists, &error);
    if (CFEqual(pathExists, kCFBooleanTrue)) {
      /* WMLogError("%@.plist does exist.", domainName); */
      result = kCFPropertyListXMLFormat_v1_0;
    }
    else {
      /* WMLogError("No %@.plist exists.", domainName); */
    }
    CFRelease(xmlURL);
  }
  
  if (!result && (format == 0 || format == kCFPropertyListOpenStepFormat)) {
    pathExists = CFURLCreatePropertyFromResource(kCFAllocatorDefault, osURL,
                                                 kCFURLFileExists, &error);
    if (CFEqual(pathExists, kCFBooleanTrue)) {
      /* WMLogError("%@ does exist.", domainName); */
      result = kCFPropertyListOpenStepFormat;
    }
    else {
      /* WMLogError("No %@ exists.", domainName); */
    }
  }
  
  CFRelease(osURL);

  return result;
}

CFAbsoluteTime WMUserDefaultsFileModificationTime(CFStringRef domainName,
                                                  CFPropertyListFormat format)
{
  CFURLRef osURL = NULL;
  CFURLRef fileURL = NULL;
  CFPropertyListFormat existingFormat = 0;
  int error;
  CFDateRef date = NULL;
  CFAbsoluteTime time = 0.0;

  osURL = WMUserDefaultsCopyURLForDomain(domainName);
  existingFormat = WMUserDefaultsFileExists(domainName, 0);
  
  if (existingFormat == kCFPropertyListXMLFormat_v1_0) {
    /* WMLogError("XML file exists for domain %@...", domainName); */
    fileURL = CFURLCreateCopyAppendingPathExtension(kCFAllocatorDefault, osURL, CFSTR("plist"));
    CFRelease(osURL);
  }
  else if (existingFormat == kCFPropertyListOpenStepFormat) {
    /* WMLogError("OpenStep file exists for domain %@...", domainName); */
    fileURL = osURL;
  }
  
  if (fileURL) {
    date = CFURLCreatePropertyFromResource(kCFAllocatorDefault, fileURL,
                                           kCFURLFileLastModificationTime, &error);
    if (error == 0) {
      time = CFDateGetAbsoluteTime(date);
    }
    CFRelease(date);
    CFRelease(fileURL);
  }

  return time;
}

CFPropertyListRef WMUserDefaultsReadFromFile(CFURLRef fileURL)
{
  CFReadStreamRef readStream = NULL;
  CFErrorRef plError = NULL;
  CFPropertyListRef pl = NULL;
  
  readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, fileURL);
  if (readStream) {
    CFReadStreamOpen(readStream);
    pl = CFPropertyListCreateWithStream(kCFAllocatorDefault, readStream, 0,
                                        kCFPropertyListMutableContainersAndLeaves,
                                        NULL, &plError);
    CFReadStreamClose(readStream);
    CFRelease(readStream);
  }
  else {
    WMLogError("cannot open READ stream to %@", fileURL);
  }
  
  if (plError && CFErrorGetCode(plError) > 0) {
    WMLogError("Failed to read user defaults from %@ (Error: %li)", fileURL, CFErrorGetCode(plError));
  }

  return pl;
}
  
CFPropertyListRef WMUserDefaultsRead(CFStringRef domainName, Boolean useSystemDomain)
{
  CFURLRef fileURL = NULL;
  CFURLRef osURL = NULL;
  CFPropertyListRef pl = NULL;

  osURL = WMUserDefaultsCopyURLForDomain(domainName);
  if (WMUserDefaultsFileExists(domainName, kCFPropertyListXMLFormat_v1_0) > 0.0) {
    // Read XML format .plist file
    fileURL = CFURLCreateCopyAppendingPathExtension(kCFAllocatorDefault, osURL, CFSTR("plist"));
  }
  else if (WMUserDefaultsFileExists(domainName, kCFPropertyListOpenStepFormat) > 0.0) {
    // Read OpenStep format (file without .plist extension)
    fileURL = osURL;
    CFRetain(osURL);
  }
  else if (useSystemDomain == true) {
    fileURL = WMUserDefaultsCopySystemURLForDomain(domainName);
  }
  else {
    WMLogError("no files exist to read for domain %@", domainName);
  }

  if (fileURL) {
    pl = WMUserDefaultsReadFromFile(fileURL);
    CFRelease(fileURL);
  }
  CFRelease(osURL);
  
  return pl;
}

Boolean WMUserDefaultsWrite(CFTypeRef dictionary, CFStringRef domainName)
{
  CFStringRef defaultsPath;
  const char *defaults_path;
  Boolean isPathGood;
  CFURLRef osURL = NULL;
  CFURLRef xmlURL = NULL;
  CFWriteStreamRef writeStream = NULL;
  CFErrorRef plError = NULL;
  Boolean isDictionaryEmpty = false;

  // Check directory hierarchy first
  /* defaultsPath = CFURLGetString(WMUserDefaultsCopyURLForDomain(domainName)); */
  defaultsPath = CFURLCopyFileSystemPath(WMUserDefaultsCopyURLForDomain(CFSTR("")),
                                         kCFURLPOSIXPathStyle);
  WMLogError("Check if user defaults path exists: %@", defaultsPath);
  defaults_path = WMUserDefaultsGetCString(defaultsPath, kCFStringEncodingUTF8);
  isPathGood = WMCreateDirectoriesAtPath(defaults_path);
  free((void *)defaults_path);
  CFRelease(defaultsPath);
  if (isPathGood == false) {
    WMLogError("Domain %@ write failed. User defaults path doesn't exist.", domainName);
    return false;
  }
  
  osURL = WMUserDefaultsCopyURLForDomain(domainName);
  xmlURL = CFURLCreateCopyAppendingPathExtension(kCFAllocatorDefault, osURL, CFSTR("plist"));
  CFRelease(osURL);

  WMLogError("about to write property list to %@", xmlURL);
  
  if (dictionary == NULL) {
    WMLogError("cannot write a NULL property list to %@", xmlURL);
    return false;
  }

  if ((CFGetTypeID(dictionary) == CFArrayGetTypeID())
      && CFArrayGetCount(dictionary) <= 0 ) {
    isDictionaryEmpty = true;
  }
  if ((CFGetTypeID(dictionary) == CFDictionaryGetTypeID())
      && CFDictionaryGetCount(dictionary) <= 0 ) {
    isDictionaryEmpty = true;
  }
  
  /* If dictionary is empty: do not write to file and remove file if exists. */
  if (isDictionaryEmpty) {
    WMLogError("got empty property list for %@", xmlURL);
    if (WMUserDefaultsFileExists(domainName, kCFPropertyListXMLFormat_v1_0) != 0) {
      unsigned char file_path[MAXPATHLEN];
      CFURLGetFileSystemRepresentation(xmlURL, false, file_path, MAXPATHLEN);
      unlink((const char *)file_path);
    }
    return true;
  }

  if (CFPropertyListIsValid(dictionary, kCFPropertyListXMLFormat_v1_0) == false) {
    WMLogError("cannot write a invalid property list to %@", xmlURL);
    return false;
  }

  writeStream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, xmlURL);
  if (writeStream) {
    CFWriteStreamOpen(writeStream);
    /*  kCFPropertyListOpenStepFormat is not supported for writing */
    CFPropertyListWrite(dictionary, writeStream, kCFPropertyListXMLFormat_v1_0, 0, &plError);
    CFWriteStreamClose(writeStream);
  }
  else {
    WMLogError("cannot open WRITE stream to %@", xmlURL);
  }

  if (plError && CFErrorGetCode(plError) > 0) {
    WMLogError("cannot write user defaults to %@ (error: %li)", xmlURL, CFErrorGetCode(plError));
  }

  CFRelease(xmlURL);

  return (plError > 0) ? false : true;
}

void WMUserDefaultsMerge(CFMutableDictionaryRef dest, CFDictionaryRef source)
{
  const void *keys;
  const void *values;

  CFDictionaryGetKeysAndValues(source, &keys, &values);
  
  for (int i = 0; i < CFDictionaryGetCount(source); i++) {
    CFDictionarySetValue(dest, &keys[i], &values[i]);
  }
}

