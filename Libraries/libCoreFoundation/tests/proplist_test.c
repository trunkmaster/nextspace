#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFLogUtilities.h>

int main(int argc, char *argv[])
{
  CFStringRef      defsPath;
  CFURLRef         defsURL;
  CFReadStreamRef  defsRead;
  /* CFWriteStreamRef defsWrite; */

  CFLog(kCFLogLevelError, CFSTR("Hello, I'm CoreFoundation test!"));

  defsPath = CFSTR("/Users/me/Library/Preferences/.NextSpace/Login");
  /* defsPath = CFSTR("/Users/me/Library/Preferences/NSGlobalDomain.plist"); */
  CFShow(defsPath);
  defsURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, defsPath,
                                          kCFURLPOSIXPathStyle, false);
  CFShow(defsURL);
  defsRead = CFReadStreamCreateWithFile(kCFAllocatorDefault, defsURL);
  CFShow(defsRead);
  
  CFErrorRef myError;
  CFPropertyListRef propList;
  CFPropertyListFormat format = kCFPropertyListOpenStepFormat;
  CFReadStreamOpen(defsRead);
  propList = CFPropertyListCreateWithStream(kCFAllocatorDefault,
                                            defsRead, 0, 0,
                                            &format,
                                            &myError);
  CFReadStreamClose(defsRead);

  /* if (myError) { */
  /*   CFLog(kCFLogLevelError, CFSTR("Error after reading %s: %s"), */
  /*         CFStringGetCStringPtr(defsPath, kCFStringEncodingISOLatin1), */
  /*         CFStringGetCStringPtr(CFErrorCopyDescription(myError), */
  /*                               kCFStringEncodingISOLatin1)); */
  /* } */

  /* CFDataRef defsData; */
  /* CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, defsURL, */
  /*                                          &defsData, NULL, NULL, NULL); */
  /* propList = CFPropertyListCreateWithData(kCFAllocatorDefault, defsData, */
  /*                                         kCFPropertyListImmutable, NULL, */
  /*                                         &myError); */

  CFShow(propList);

  CFRelease(propList);
  CFRelease(defsRead);
  CFRelease(defsURL);
  CFRelease(defsPath);

  CFShow(CFSTR("Proper list after release:"));
  CFShow(propList);

  /**/
  const char *number = "500";
  const char *string;
  const char *array;
  const char *dictionary;
  CFPropertyListFormat plFormat = kCFPropertyListOpenStepFormat;
  CFErrorRef plError;
  CFPropertyListRef pl;
  CFDataRef data;

  // CFDataCreateWithBytesNoCopy(CFAllocatorRef allocator, const UInt8 *bytes, CFIndex length, CFAllocatorRef bytesDeallocator);
  data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, number, strlen(number), kCFAllocatorNull);
  // CFPropertyListCreateWithData(CFAllocatorRef allocator, CFDataRef data, CFOptionFlags options, CFPropertyListFormat *format, CFErrorRef *error)
  pl = CFPropertyListCreateWithData(kCFAllocatorDefault, data, 0, &plFormat, plError);
  
  return (0);
}
