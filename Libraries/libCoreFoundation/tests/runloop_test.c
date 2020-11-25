// cc test.c -framework CoreFoundation -O

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFFileDescriptor.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <X11/Xlib.h>

static void fdCallBack(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info)
{
  int fd = CFFileDescriptorGetNativeDescriptor(fdref);

  // take action on death of process here
  printf("callout on descriptor '%i'\n", fd);
  
  CFFileDescriptorInvalidate(fdref);
  CFRelease(fdref); // the CFFileDescriptorRef is no longer of any use in this example
  close(fd);
}

static void timerCB(CFRunLoopTimerRef timer, void *data)
{
  fprintf(stderr, "Timer was fired: %s\n", (char *)data);
}

// one argument, an integer pid to watch, required
int main(int argc, char *argv[])
{
  CFFileDescriptorRef fdRef;
  CFRunLoopSourceRef rlSource;
  int fd;
  Display *dpy = NULL;
  
  if (argc < 2) {
    dpy = XOpenDisplay(getenv("DISPLAY"));
    fd = ConnectionNumber(dpy);
  }
  else {  
    fd = open(argv[1], O_RDONLY);
  }
  
  fdRef = CFFileDescriptorCreate(kCFAllocatorDefault, fd, true, fdCallBack, NULL);
  CFFileDescriptorEnableCallBacks(fdRef, kCFFileDescriptorReadCallBack);
  
  rlSource = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdRef, 0);
  CFRunLoopAddSource(CFRunLoopGetMain(), rlSource, kCFRunLoopDefaultMode);
  CFRelease(rlSource);

  CFRunLoopTimerContext ctx = {0, "RunLoopTimer", NULL, NULL, 0};
  CFRunLoopTimerRef timer =  CFRunLoopTimerCreate(kCFAllocatorDefault,
                                                  CFAbsoluteTimeGetCurrent() + 3,
                                                  0, 0, 0, timerCB, &ctx);
  CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
  CFRelease(timer);

  // run the run loop for 20 seconds
  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 6, false);

  if (dpy) {
    XCloseDisplay(dpy);
  }
  
  return 0;
}
