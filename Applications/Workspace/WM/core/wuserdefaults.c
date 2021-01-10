#include <CoreFoundation/CFLogUtilities.h>

#include "defaults.h"
#include "wuserdefaults.h"

// ---[ Location ] --------------------------------------------------------------------------------

// /Users/$USER/Library
#define USER_LIBRARY_DIR "Library"
CFURLRef WMUserDefaultsCopyUserLibraryURL(void)
{
  CFURLRef homePath = CFCopyHomeDirectoryURL();
  CFURLRef libPath;

  libPath = CFURLCreateCopyAppendingPathComponent(NULL, homePath, CFSTR(USER_LIBRARY_DIR), true);
  CFRelease(homePath);

  return libPath;
}

// $USER_LIBRARY_DIR/Preferences/.NextSpace
/* #define DEFAULTS_SUBDIR "Preferences/.NextSpace" */
#define DEFAULTS_SUBDIR "Preferences/.WindowMaker"

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

CFStringRef WMUserDefaultsCopyPathForDomain(CFStringRef domain)
{
  CFURLRef    domainURL;
  CFStringRef domainPath;

  domainURL = WMUserDefaultsCopyURLForDomain(domain);
  domainPath = CFURLCopyFileSystemPath(domainURL, kCFURLPOSIXPathStyle);
  CFRelease(domainURL);
  
  return domainPath;
}

CFURLRef WMUserDefaultsCopySystemURLForDomain(CFStringRef domain)
{
  CFURLRef appBundleURL;
  CFURLRef domainURL;

  appBundleURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR(SYSCONFDIR),
                                               kCFURLPOSIXPathStyle, true);
  
  if (CFStringGetLength(domain) > 0) {
    domainURL = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, appBundleURL,
                                                      domain, false);
  }
  else {
    CFRetain(appBundleURL);
    domainURL = appBundleURL;
  }

  CFRelease(appBundleURL);

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
      /* CFLog(kCFLogLevelError, CFSTR("%@.plist does exist."), domainName); */
      result = kCFPropertyListXMLFormat_v1_0;
    }
    else {
      /* CFLog(kCFLogLevelError, CFSTR("No %@.plist exists."), domainName); */
    }
    CFRelease(xmlURL);
  }
  
  if (!result && (format == 0 || format == kCFPropertyListOpenStepFormat)) {
    pathExists = CFURLCreatePropertyFromResource(kCFAllocatorDefault, osURL,
                                                 kCFURLFileExists, &error);
    if (CFEqual(pathExists, kCFBooleanTrue)) {
      /* CFLog(kCFLogLevelError, CFSTR("%@ does exist."), domainName); */
      result = kCFPropertyListOpenStepFormat;
    }
    else {
      /* CFLog(kCFLogLevelError, CFSTR("No %@ exists."), domainName); */
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
    /* CFLog(kCFLogLevelError, CFSTR("XML file exists for domain %@..."), domainName); */
    fileURL = CFURLCreateCopyAppendingPathExtension(kCFAllocatorDefault, osURL, CFSTR("plist"));
    CFRelease(osURL);
  }
  else if (existingFormat == kCFPropertyListOpenStepFormat) {
    /* CFLog(kCFLogLevelError, CFSTR("OpenStep file exists for domain %@..."), domainName); */
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
    CFLog(kCFLogLevelError, CFSTR("** %s (%s:%i) cannot open READ stream to %@"),
          __FILE__, __FUNCTION__, __LINE__, fileURL);
  }
  
  if (plError > 0) {
    CFLog(kCFLogLevelError, CFSTR("** %s (%s:%i) Failed to read user defaults from %@ (Error: %i)"),
          __FILE__, __FUNCTION__, __LINE__, fileURL, plError);
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
    CFLog(kCFLogLevelError, CFSTR("** %s (%s:%i) no files exist to read for domain %@"),
          __FILE__, __FUNCTION__, __LINE__, domainName);
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
  CFURLRef osURL = NULL;
  CFURLRef xmlURL = NULL;
  CFWriteStreamRef writeStream = NULL;
  CFErrorRef plError = NULL;
  Boolean isDictionaryEmpty = false;

  osURL = WMUserDefaultsCopyURLForDomain(domainName);
  xmlURL = CFURLCreateCopyAppendingPathExtension(kCFAllocatorDefault, osURL, CFSTR("plist"));
  CFRelease(osURL);

  CFLog(kCFLogLevelError, CFSTR("* %s (%s) about to write property list to %@"),
        __FILE__, __FUNCTION__, xmlURL);
  
  if (dictionary == NULL) {
    CFLog(kCFLogLevelError, CFSTR("** cannot write a NULL property list to %@"), xmlURL);
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
    CFLog(kCFLogLevelError, CFSTR("** got empty property list for %@"), xmlURL);
    if (WMUserDefaultsFileExists(domainName, kCFPropertyListXMLFormat_v1_0) != 0) {
      unsigned char file_path[MAXPATHLEN];
      CFURLGetFileSystemRepresentation(xmlURL, false, file_path, MAXPATHLEN);
      unlink((const char *)file_path);
    }
    return true;
  }

  if (CFPropertyListIsValid(dictionary, kCFPropertyListXMLFormat_v1_0) == false) {
    CFLog(kCFLogLevelError, CFSTR("** cannot write a invalid property list to %@"), xmlURL);
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
    CFLog(kCFLogLevelError, CFSTR("*** %s (%s:%s) cannot open WRITE stream to %@"),
          __FILE__, __FUNCTION__, __LINE__, xmlURL);
  }

  if (plError > 0) {
    CFLog(kCFLogLevelError, CFSTR("*** cannot write user defaults to %@ (error: %i)"),
          xmlURL, plError);
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

