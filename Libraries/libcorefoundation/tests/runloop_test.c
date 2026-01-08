// cc test.c -framework CoreFoundation -O

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFFileDescriptor.h>
#include <CoreFoundation/CFLogUtilities.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <X11/Xlib.h>

// static void timerCB(CFRunLoopTimerRef timer, void *data)
// {
//   fprintf(stderr, "Timer was fired: %s runloop: %p\n", (char *)data, CFRunLoopGetCurrent());
// }

// static void setupRunLoop1(char *file)
// {
//   CFFileDescriptorRef fdRef;
//   CFRunLoopSourceRef rlSource;
//   int fd = open(file, O_RDONLY);

//   fdRef = CFFileDescriptorCreate(kCFAllocatorDefault, fd, true, fdCallBack, NULL);
//   CFFileDescriptorEnableCallBacks(fdRef, kCFFileDescriptorReadCallBack);

//   rlSource = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdRef, 1);
//   CFRunLoopAddSource(CFRunLoopGetCurrent(), rlSource, kCFRunLoopDefaultMode);
//   CFRelease(rlSource);

//   /* CFRunLoopTimerContext ctx = {0, "RunLoopTimer1", NULL, NULL, 0}; */
//   /* CFRunLoopTimerRef timer =  CFRunLoopTimerCreate(kCFAllocatorDefault, */
//   /*                                                 CFAbsoluteTimeGetCurrent() + 3, */
//   /*                                                 0, 0, 0, timerCB, &ctx); */
//   /* CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode); */
//   /* CFRelease(timer); */

//   /* CFRunLoopRunInMode(kCFRunLoopDefaultMode, 6, false); */
//   /* close(fd); */
// }

static int CantManageScreen = 0;
static int _wmRunningErrorHandler(Display *dpy, XErrorEvent *error)
{
  CantManageScreen = 1;
  return -1;
}

static Display *xDisplay = NULL;
static long event_mask;
static int xScreen = -1;

static void fdCallBack(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info)
{
  int fd = CFFileDescriptorGetNativeDescriptor(fdref);
  XEvent event;

  // take action on death of process here
  printf("callout on descriptor '%i'\n", fd);

  while (XPending(xDisplay) > 0) {
    XNextEvent(xDisplay, &event);
  }

  CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
  // CFFileDescriptorInvalidate(fdref);
  // CFRelease(fdref);  // the CFFileDescriptorRef is no longer of any use in this example
  // close(fd);
}

static Bool startWindowManager(void)
{
  XErrorHandler oldHandler;

  oldHandler = XSetErrorHandler((XErrorHandler)_wmRunningErrorHandler);
  event_mask = SubstructureRedirectMask;

  xDisplay = XOpenDisplay(NULL);
  xScreen = DefaultScreen(xDisplay);
  XSelectInput(xDisplay, RootWindow(xDisplay, xScreen), event_mask);

  XSync(xDisplay, False);
  XSetErrorHandler(oldHandler);

  if (CantManageScreen) {
    CFLog(kCFLogLevelError, CFSTR("%s: Can't open display"), __func__);
    return False;
  } else {
    // XCloseDisplay(xDisplay);
    return True;
  }
}

static void stopWindowManager(void)
{
  event_mask &= ~(SubstructureRedirectMask);
  XSelectInput(xDisplay, RootWindow(xDisplay, xScreen), event_mask);
  XSync(xDisplay, False);
  XCloseDisplay(xDisplay);  
}

// one argument, an integer pid to watch, required
int main(int argc, char *argv[])
{
  CFFileDescriptorRef fdRef;
  CFRunLoopSourceRef rlSource;
  int fd;
  // Display *dpy = NULL;

  if (argc < 2) {
    char *display_name = getenv("DISPLAY");
    if (display_name == NULL) {

    }
    if (startWindowManager() == False) {
      return 1;
    }
    fd = ConnectionNumber(xDisplay);
  } else {
    fd = open(argv[1], O_RDONLY);
  }

  fprintf(stderr, "= START: runloop setup: %p (main: %p) FD: %i\n", CFRunLoopGetCurrent(),
          CFRunLoopGetMain(), fd);

  // File descriptor
  fdRef = CFFileDescriptorCreate(kCFAllocatorDefault, fd, true, fdCallBack, NULL);
  CFFileDescriptorEnableCallBacks(fdRef, kCFFileDescriptorReadCallBack);
  // Runloop
  rlSource = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdRef, 0);
  CFRunLoopAddSource(CFRunLoopGetCurrent(), rlSource, kCFRunLoopDefaultMode);
  CFRelease(rlSource);

  /* CFRunLoopTimerContext ctx = {0, "RunLoopTimer", NULL, NULL, 0}; */
  /* CFRunLoopTimerRef timer =  CFRunLoopTimerCreate(kCFAllocatorDefault, */
  /*                                                 CFAbsoluteTimeGetCurrent() + 3, */
  /*                                                 0, 0, 0, timerCB, &ctx); */
  /* CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode); */
  /* CFRelease(timer); */

  fprintf(stderr, "= FINISH: runloop setup: %p (main: %p)\n", CFRunLoopGetCurrent(),
          CFRunLoopGetMain());

  // new thread
  // dispatch_queue_t wm_q = dispatch_queue_create("ns.workspace.wm", DISPATCH_QUEUE_CONCURRENT);
  // dispatch_async(wm_q, ^{
  //   fprintf(stderr, "= START: setup runloop: %p (main: %p)\n", CFRunLoopGetCurrent(),
  //           CFRunLoopGetMain());
  //   setupRunLoop1(argv[1]);
  //   fprintf(stderr, "= FINISH: setup runloop: %p (main: %p)\n", CFRunLoopGetCurrent(),
  //           CFRunLoopGetMain());
  //   CFRunLoopRunInMode(kCFRunLoopDefaultMode, 6, false);
  //   fprintf(stderr, "= QUIT: runloop: %p (main: %p)\n", CFRunLoopGetCurrent(), CFRunLoopGetMain());
  // });

  // run the run loop for 20 seconds
  // CFRunLoopRunInMode(kCFRunLoopDefaultMode, 6, false);
  CFRunLoopRun();
  // dispatch_main();

  // if (dpy) {
  //   XCloseDisplay(dpy);
  // }
  stopWindowManager();

  return 0;
}
