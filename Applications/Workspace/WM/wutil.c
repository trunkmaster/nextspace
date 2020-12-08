#include <CoreFoundation/CFLogUtilities.h>
#include <pwd.h>
#include <sys/param.h>

#include "wutil.h"

static char *_wgetenv(const char *n)
{
#ifdef HAVE_SECURE_GETENV
  return secure_getenv(n);
#else
  return getenv(n);
#endif  
}

CFStringRef WMUserName()
{
  struct passwd *user = NULL;
  CFStringRef username = NULL;

  user = getpwuid(getuid());
  if (user) {
    username = CFStringCreateWithCString(kCFAllocatorDefault, user->pw_name, kCFStringEncodingUTF8);
  }

  return username;
}

CFStringRef WMHomePathForUser(CFStringRef username)
{
  CFStringRef home = NULL;
  CFStringRef errorMessage = NULL;
  struct passwd *upwd = NULL;
    
  if (username) {
    upwd = getpwnam(CFStringGetCStringPtr(username, kCFStringEncodingASCII));
  }
  else {
    upwd = getpwuid(geteuid() ?: getuid());
  }
    
  if (upwd) {
    if (upwd->pw_dir) {
      home = CFStringCreateWithCString(kCFAllocatorDefault, upwd->pw_dir, kCFStringEncodingUTF8);
    }
    else {
      errorMessage = CFSTR("error: upwd->pw_dir is NULL");
    }
  }
  else {
    char *pwh = _wgetenv("HOME");
    if (pwh) {
      home = CFStringCreateWithCString(kCFAllocatorDefault, pwh, kCFStringEncodingUTF8);
    }
    else {
      errorMessage = CFSTR("error: failed to get value of HOME environment variable");
    }
  }
  /* else if (!username) { */
  /*   errorMessage = CFSTR("error: faled to get /etc/password entry (getpwuid)"); */
  /* } */

  if (errorMessage) {
    CFLog(kCFLogLevelError, errorMessage);
    CFRelease(errorMessage);
  }

  return home;
}


// ~/Library
CFStringRef WMUserLibraryPath()
{
  return CFStringCreateWithFormat(NULL, NULL, CFSTR("%@/%s"), WMHomePathForUser(NULL), "/Library");
}

#define DEFAULTS_SUBDIR "Preferences/.WindowMaker"
// ~/Library/Preferences/.WindowMaker/domain
CFStringRef WMPathForDefaultsDomain(CFStringRef domain)
{
  return CFStringCreateWithFormat(NULL, NULL, CFSTR("%@/%s/%@"),
                                  WMUserLibraryPath(), DEFAULTS_SUBDIR, domain);
}
