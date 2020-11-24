// cc test.c -framework CoreFoundation -O

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFFileDescriptor.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
/* #include <sys/event.h> */

static void fdCallBack(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info)
{
  int fd = CFFileDescriptorGetNativeDescriptor(fdref);

  // take action on death of process here
  printf("callout on descriptor '%i'\n", fd);
  
  CFFileDescriptorInvalidate(fdref);
  CFRelease(fdref); // the CFFileDescriptorRef is no longer of any use in this example
  close(fd);
}

// one argument, an integer pid to watch, required
int main(int argc, char *argv[])
{
  CFFileDescriptorRef fdRef;
  CFRunLoopSourceRef rlSource;
  
  if (argc < 2) exit(1);
  
  int fd = open(argv[1], O_RDONLY);
  fdRef = CFFileDescriptorCreate(kCFAllocatorDefault, fd, true, fdCallBack, NULL);
  CFFileDescriptorEnableCallBacks(fdRef, kCFFileDescriptorWriteCallBack);
  
  rlSource = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdRef, 0);
  CFRunLoopAddSource(CFRunLoopGetMain(), rlSource, kCFRunLoopDefaultMode);
  CFRelease(rlSource);

  // run the run loop for 20 seconds
  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 20.0, false);
  return 0;
}
