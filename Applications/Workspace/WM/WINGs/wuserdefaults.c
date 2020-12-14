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
  /* CFPropertyListFormat plFormat = kCFPropertyListOpenStepFormat; */
  CFReadStreamRef      readStream;
  CFErrorRef           plError = NULL;
  CFPropertyListRef    pl = NULL;

  readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, pathURL);
  if (readStream) {
    CFReadStreamOpen(readStream);
    pl = CFPropertyListCreateWithStream(kCFAllocatorDefault, readStream, 0,
                                        kCFPropertyListMutableContainersAndLeaves,
                                        NULL, &plError);
    CFReadStreamClose(readStream);
    CFRelease(readStream);
  }
  else {
    CFLog(kCFLogLevelError, CFSTR("%s() cannot open READ stream to %@"),
          __PRETTY_FUNCTION__, pathURL);
  }
  
  if (plError > 0) {
    CFLog(kCFLogLevelError, CFSTR("Failed to read user defaults from %@ (Error: %i)"),
          pathURL, plError);
  }

  /* CFShow(pl); */

  return pl;
}

Boolean WMUserDefaultsWrite(CFDictionaryRef dictionary, CFURLRef fileURL)
{
  CFWriteStreamRef writeStream;
  CFErrorRef       plError = NULL;

  CFLog(kCFLogLevelError, CFSTR("* %s (%s:%s) about to write property list to %@"),
        __FILE__, __FUNCTION__, __LINE__, fileURL);
  
  if (dictionary == NULL) {
    CFLog(kCFLogLevelError, CFSTR("** %s (%s:%s) cannot write a NULL property list to %@"),
          __FILE__, __FUNCTION__, __LINE__, fileURL);
    return false;
  }
  if (CFPropertyListIsValid(dictionary, kCFPropertyListXMLFormat_v1_0) == false) {
    CFLog(kCFLogLevelError, CFSTR("** %s (%s:%s) cannot write a invalid property list to %@\n %@"),
          __FILE__, __FUNCTION__, __LINE__, fileURL, dictionary);
    return false;
  }
  
  writeStream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, fileURL);
  if (writeStream) {
    CFWriteStreamOpen(writeStream);
    /*  kCFPropertyListOpenStepFormat is not supported for writing */
    CFPropertyListWrite(dictionary, writeStream, kCFPropertyListXMLFormat_v1_0, 0, &plError);
    CFWriteStreamClose(writeStream);
  }
  else {
    CFLog(kCFLogLevelError, CFSTR("** %s (%s:%s) cannot open WRITE stream to %@"),
          __FILE__, __FUNCTION__, __LINE__, fileURL);
  }

  if (plError > 0) {
    CFLog(kCFLogLevelError, CFSTR("Error writing user defaults at %@ = %u"), fileURL, plError);
  }

  return (plError > 0) ? false : true;
}

Boolean WMUserDefaultsSynchronize(WDDomain *domain)
{
  /* struct stat stbuf; */
  /* char path[PATH_MAX]; */
  /* WMPropList *shared_dict; */
  /* Boolean freeDict = False; */
  Boolean result;

  /* if (CFGetTypeID(domain->dictionary) != CFDictionaryGetTypeID()) { */
  /*   /\* retrieve global system dictionary *\/ */
  /*   snprintf(path, sizeof(path), "%s/WindowMaker/%s", SYSCONFDIR, domain->domain_name); */
  /*   if (stat(path, &stbuf) >= 0) { */
  /*     shared_dict = WMReadPropListFromFile(path); */
  /*     if (shared_dict) { */
  /*       if (WMIsPLDictionary(shared_dict)) { */
  /*         freeDict = True; */
  /*         dict = WMDeepCopyPropList(domain->dictionary); */
  /*         WMSubtractPLDictionaries(dict, shared_dict, True); */
  /*       } */
  /*       WMReleasePropList(shared_dict); */
  /*     } */
  /*   } */
  /* } */

  CFLog(kCFLogLevelError, CFSTR("Writing domain: %@ at path: %@"), domain->name, domain->path);

  result = WMUserDefaultsWrite(domain->dictionary, domain->path);
  CFRelease(domain->dictionary);
  domain->dictionary = (CFMutableDictionaryRef)WMUserDefaultsRead(domain->path);

  return (result && domain->dictionary != NULL);
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

