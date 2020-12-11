#include <CoreFoundation/CFLogUtilities.h>
/* #include <pwd.h> */
/* #include <sys/param.h> */

#include "wuserdefaults.h"

// ---[ Defaults locations ] ----------------------------------------------------------------------

/* static char *_wgetenv(const char *n) */
/* { */
/* #ifdef HAVE_SECURE_GETENV */
/*   return secure_getenv(n); */
/* #else */
/*   return getenv(n); */
/* #endif   */
/* } */

/* CFStringRef WMUserName() */
/* { */
/*   struct passwd *user = NULL; */
/*   CFStringRef username = NULL; */

/*   user = getpwuid(getuid()); */
/*   if (user) { */
/*     username = CFStringCreateWithCString(kCFAllocatorDefault, user->pw_name, kCFStringEncodingUTF8); */
/*   } */

/*   return username; */
/* } */

/* CFStringRef WMHomePathForUser(CFStringRef username) */
/* { */
/*   CFStringRef home = NULL; */
/*   CFStringRef errorMessage = NULL; */
/*   struct passwd *upwd = NULL; */
    
/*   if (username) { */
/*     upwd = getpwnam(CFStringGetCStringPtr(username, kCFStringEncodingUTF8)); */
/*   } */
/*   else { */
/*     upwd = getpwuid(geteuid() ?: getuid()); */
/*   } */
    
/*   if (upwd) { */
/*     if (upwd->pw_dir) { */
/*       home = CFStringCreateWithCString(kCFAllocatorDefault, upwd->pw_dir, kCFStringEncodingUTF8); */
/*     } */
/*     else { */
/*       errorMessage = CFSTR("error: upwd->pw_dir is NULL"); */
/*     } */
/*   } */
/*   else { */
/*     char *pwh = _wgetenv("HOME"); */
/*     if (pwh) { */
/*       home = CFStringCreateWithCString(kCFAllocatorDefault, pwh, kCFStringEncodingUTF8); */
/*     } */
/*     else { */
/*       errorMessage = CFSTR("error: failed to get value of HOME environment variable"); */
/*     } */
/*   } */
/*   /\* else if (!username) { *\/ */
/*   /\*   errorMessage = CFSTR("error: faled to get /etc/password entry (getpwuid)"); *\/ */
/*   /\* } *\/ */

/*   if (errorMessage) { */
/*     CFLog(kCFLogLevelError, errorMessage); */
/*     CFRelease(errorMessage); */
/*   } */

/*   return home; */
/* } */

// ~/Library
CFURLRef WMUserDefaultsCopyUserLibraryURL(void)
{
  CFURLRef homePath = CFCopyHomeDirectoryURL();
  CFURLRef libPath;

  libPath = CFURLCreateCopyAppendingPathComponent(NULL, homePath, CFSTR("Library"), true);
  CFRelease(homePath);

  CFShow(libPath);
  
  return libPath;
}

#define DEFAULTS_SUBDIR "Preferences/.WindowMaker"
// ~/Library/Preferences/.WindowMaker/domain
CFURLRef WMUserDefaultsCopyURLForDomain(CFStringRef domain)
{
  CFURLRef libURL, prefsURL, wmURL;
  CFURLRef domainURL;

  libURL = WMUserDefaultsCopyUserLibraryURL();
  prefsURL = CFURLCreateCopyAppendingPathComponent(NULL, libURL, CFSTR("Preferences"), true);
  CFRelease(libURL);
  wmURL = CFURLCreateCopyAppendingPathComponent(NULL, prefsURL, CFSTR(".WindowMaker"), true);
  CFRelease(prefsURL);

  if (CFStringGetLength(domain) > 0) {
    domainURL = CFURLCreateCopyAppendingPathComponent(NULL, wmURL, domain, false);
  }
  else {
    CFRetain(wmURL);
    domainURL = wmURL;
  }
  CFRelease(wmURL);

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

CFAbsoluteTime WMUserDefaultsFileModificationTime(CFURLRef pathURL)
{
  CFBooleanRef   pathExists;
  int            error;
  CFDateRef      date = NULL;
  CFAbsoluteTime time = 0.0;

  pathExists = CFURLCreatePropertyFromResource(kCFAllocatorDefault, pathURL,
                                               kCFURLFileExists, &error);
  if (CFEqual(pathExists, kCFBooleanTrue)) {
    date = CFURLCreatePropertyFromResource(kCFAllocatorDefault, pathURL,
                                           kCFURLFileLastModificationTime,
                                           &error);
    if (error == 0) {
      time = CFDateGetAbsoluteTime(date);
    }
    CFRelease(date);
  }

  return time;
}

CFPropertyListRef WMUserDefaultsRead(CFURLRef pathURL)
{
  CFPropertyListFormat plFormat = kCFPropertyListOpenStepFormat;
  CFReadStreamRef      readStream;
  CFErrorRef           plError = NULL;
  CFPropertyListRef    pl;
  
  readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, pathURL);
  CFReadStreamOpen(readStream);
  pl = CFPropertyListCreateWithStream(kCFAllocatorDefault, readStream, 0,
                                      kCFPropertyListMutableContainersAndLeaves,
                                      &plFormat, &plError);
  CFReadStreamClose(readStream);
  CFRelease(readStream);
  
  if (plError > 0) {
    CFLog(kCFLogLevelError, CFSTR("Failed to read user defaults from %@ (Error: %i)"),
          pathURL, plError);
  }

  return pl;
}

Boolean WMUserDefaultsWrite(CFDictionaryRef dictionary, CFURLRef fileURL)
{
  CFWriteStreamRef  writeStream;
  /* CFPropertyListRef propertyList; */
  CFErrorRef        plError;

  writeStream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, fileURL);
  /* CFPropertyListCreateWithData(CFAllocatorRef allocator, */
  /*                              CFDataRef data, */
  /*                              CFOptionFlags options, */
  /*                              &plFormat, &plError) */
  CFPropertyListWrite(dictionary, writeStream, kCFPropertyListOpenStepFormat, 0, &plError);

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

