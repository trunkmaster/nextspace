#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFLogUtilities.h>

void readPropertyList(void)
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
}

int main(int argc, char *argv[])
{
  readPropertyList();
  /**/
  CFLog(kCFLogLevelError, CFSTR("\n\n>>> Create proplist from char* <<<\n"));
  const unsigned *number = "500";
  const char *string;
  const unsigned *array = "WidgetColor = (solid, gray);";
  const char *dictionary;
  CFPropertyListFormat plFormat = kCFPropertyListOpenStepFormat;
  CFErrorRef plError = NULL;
  CFPropertyListRef pl;
  CFDataRef data;

  {
    CFStringRef libraryPath;
    CFURLRef    homePath = CFCopyHomeDirectoryURL();
    CFURLRef    libPath;
    CFURLRef    tmpPath;
    CFDateRef   modificationDate;
    SInt32      error;

    libraryPath = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@/%s"), CFURLGetString(homePath), "/Library");
    CFShow(libraryPath);
    
    /* CFURLCreateCopyAppendingPathComponent(CFAllocatorRef allocator, CFURLRef url, CFStringRef pathComponent, Boolean isDirectory) */
    libPath = CFURLCreateCopyAppendingPathComponent(NULL, homePath, CFSTR("Library"), false);
    CFShow(CFURLCopyFileSystemPath(homePath, kCFURLPOSIXPathStyle));
    CFShow(libPath);
    CFShow(CFURLCopyFileSystemPath(libPath, kCFURLPOSIXPathStyle));
    
    CFBooleanRef ifExists = CFURLCreatePropertyFromResource(NULL, libPath, kCFURLFileExists, &error);
    CFShow(ifExists);

    if (CFEqual(ifExists, kCFBooleanTrue)) {
      modificationDate = CFURLCreatePropertyFromResource(NULL, //CFAllocatorRef alloc,
                                                         libPath, // CFURLRef url,
                                                         kCFURLFileLastModificationTime, // CFStringRef property,
                                                         &error /*SInt32 *errorCode*/);
      if (error == 0) {
        CFCalendarRef calendar = CFCalendarCopyCurrent();
        CFAbsoluteTime absTime = CFDateGetAbsoluteTime(modificationDate);
        int year, month, day;
      
        CFShow(modificationDate);
        CFCalendarDecomposeAbsoluteTime(calendar, absTime, "yMd", &year, &month, &day);
        CFLog(kCFLogLevelError, CFSTR("%@ modification time is: %i/%i/%i"), libPath, year, month, day);
      }
      else {
        CFLog(kCFLogLevelError, CFSTR("Failed to get modification time of %@"), libPath);
      }
    }
  }

  // CFDataCreateWithBytesNoCopy(CFAllocatorRef allocator, const UInt8 *bytes, CFIndex length, CFAllocatorRef bytesDeallocator);
  data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, array, strlen(array), kCFAllocatorNull);
  // CFPropertyListCreateWithData(CFAllocatorRef allocator, CFDataRef data, CFOptionFlags options, CFPropertyListFormat *format, CFErrorRef *error)
  pl = CFPropertyListCreateWithData(kCFAllocatorDefault, data, 0, &plFormat, &plError);
  CFShow(pl);
  CFRelease(pl);
  CFRelease(data);
  
  return (0);
}
