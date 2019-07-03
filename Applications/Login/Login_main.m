/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - Login application
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#include <sys/wait.h>
#include <dispatch/dispatch.h>

#include <X11/Xlib.h>
#include <X11/cursorfont.h>
#include <X11/Xcursor/Xcursor.h>
#include <X11/extensions/Xrandr.h>

#import <AppKit/NSApplication.h>
#import <DesktopKit/NXTDefaults.h>
#import <SystemKit/OSEScreen.h>
#import <SystemKit/OSEDisplay.h>

#import "Application.h"
#import "Controller.h"

static dispatch_queue_t x_q;
static dispatch_queue_t app_q;
static Display         *dpy = NULL;

static NSTask      *xorgTask = nil;
static NXTDefaults *loginDefaults = nil;

//-----------------------------------------------------------------------------
// --- Plymouth
//-----------------------------------------------------------------------------
BOOL isPlymouthRunning()
{
  int res = system("/usr/bin/plymouth --ping");

  return (res == 0) ? YES : NO;
}

void plymouthDeactivate()
{
  if (isPlymouthRunning() == YES) {
    system("/usr/bin/plymouth deactivate");
  }
}

void plymouthQuit(BOOL withTransition)
{
  if (isPlymouthRunning() == NO)
    return;
  
  if (withTransition)
    system("/usr/bin/plymouth quit --retain-splash");
  else
    system("/usr/bin/plymouth quit");
}

void plymouthStart(int mode)
{
  system("/usr/sbin/plymouthd");
  if (isPlymouthRunning() == YES) {
    system("/usr/bin/plymouth show-splash");
    system("/usr/bin/plymouth change-mode --shutdown");
  }
}

//-----------------------------------------------------------------------------
// --- X11 ---
//-----------------------------------------------------------------------------
int startWindowServer()
{
  NSMutableArray *serverArgs;
  NSString       *server;
  Display        *xDisplay;
  Window         xRootWindow;

  setenv("DISPLAY", ":0.0", 0);
  setenv("HOME", "/root", 1);
  setenv("USER", "root", 0);

  if ((xDisplay = XOpenDisplay(NULL)) == NULL) {
    serverArgs = [[loginDefaults objectForKey:@"WindowServerCommand"] mutableCopy];
    server = [serverArgs objectAtIndex:0];
    [serverArgs removeObjectAtIndex:0];

    // Launch Xorg
    xorgTask = [[NSTask alloc] init];
    [xorgTask setLaunchPath:server];
    [xorgTask setArguments:serverArgs];
    [xorgTask setCurrentDirectoryPath:@"/"];
    NSLog(@"================> Xorg is coming up <================");
    [xorgTask launch];

    [serverArgs release];

    // Wait for X server connection
    while (xDisplay == NULL) {
      xDisplay = XOpenDisplay(NULL); // NULL == getenv("DISPLAY")
    }

    // X11 Resources
    system("xrdb -merge /etc/X11/Xresources.nextspace");
    // Root window and it's background
    xRootWindow = RootWindow(xDisplay, DefaultScreen(xDisplay));
    
    XSetWindowBackground(xDisplay, xRootWindow, 5460853L);
    XClearWindow(xDisplay, xRootWindow);
    XSync(xDisplay, false);
    
    NSLog(@"================> Xorg is ready <================");
    XCloseDisplay(xDisplay);
  }

  return 0;
}

void setupDisplays()
{
  OSEScreen  *screen = [OSEScreen sharedScreen];
  OSEDisplay *mainDisplay;
  NSArray    *layout;
  Display    *xDisplay;
  Window     xRootWindow;
  // NSArray   *systemDisplays;

  // Get layout with monitors aligned horizontally
  layout = [screen defaultLayout:YES];

  // Setup initial gamma and brightness
  // And check main display from saved layout is active
  // systemDisplays = [screen activeDisplays];
  // for (OSEDisplay *display in systemDisplays)
  //   {
  //     [display setGammaBrightness:0.0];
  //   }
  // [systemDisplays release];
  
  [screen applyDisplayLayout:layout];
  
  mainDisplay = [screen displayWithMouseCursor];
  xDisplay = XOpenDisplay(NULL);
  xRootWindow = RootWindow(xDisplay, DefaultScreen(xDisplay));
  XWarpPointer(xDisplay, None, xRootWindow, 0, 0, 0, 0,
               (int)mainDisplay.frame.origin.x + 50,
               (int)mainDisplay.frame.origin.y + 50);
  XCloseDisplay(xDisplay);
}


void prepareEventLoop()
{
  int screen;
  
  dpy = XOpenDisplay(NULL);
  screen = DefaultScreen(dpy);
  XRRSelectInput(dpy, RootWindow(dpy, screen), RRScreenChangeNotifyMask);
  XSync(dpy, False);  
}

void startEventLoop()
{
  XEvent event;

  for (;;) {
    XNextEvent(dpy, &event); // blocks here
    if (event.type & RRScreenChangeNotifyMask) {
      // Handle screen change event
      printf("[EventLoop] XrandR event received.\n");
      XRRUpdateConfiguration(&event);
    }
    else {
      printf("[EventLoop] some event received.\n");
    }
  }
}

void sendMessage(void)
{
  XEvent event;

  event.xclient.type = RRScreenChangeNotifyMask;
  event.xclient.message_type = 0L;
  event.xclient.format = 32;
  event.xclient.display = dpy;
  event.xclient.window = RootWindow(dpy, DefaultScreen(dpy));
  event.xclient.data.l[0] = 0;
  event.xclient.data.l[1] = CurrentTime;
  event.xclient.data.l[2] = 0;
  event.xclient.data.l[3] = 0;
  XSendEvent(dpy, RootWindow(dpy, DefaultScreen(dpy)), False, RRScreenChangeNotifyMask, &event);
  XSync(dpy, False);
}


//-----------------------------------------------------------------------------
// --- Misc ---
//-----------------------------------------------------------------------------
// Returns PID of running command if `wait` == NO
// Returns exit status of child process if `wait` == YES
int runCommand(NSString *command, BOOL wait)
{
  NSArray    *commandArgs;
  const char **argv;
  int        argc, pid = 0, child_status;

  commandArgs = [command componentsSeparatedByString:@" "];
  argc = [commandArgs count];
  if (argc == 0) {
    return 1;
  }
  argv = malloc((argc + 1) * sizeof(char *));

  for (int i = 0; i < argc; i++) {
    argv[i] = [[commandArgs objectAtIndex:i] cString];
  }
  argv[argc] = NULL;
  
  pid = fork();
  switch (pid)
    {
    case 0:
      execv(argv[0], (char **)argv);
      abort();
      break;
    default:
      free(argv);
      if (wait != NO)
        waitpid(pid, &child_status, 0);
      break;
    }
  return (wait == NO) ? pid : child_status;
}

static void handleSignal(int sig)
{
  fprintf(stderr, "[Login] got signal %i\n", sig);
  [NSApp stop:nil];
}

NXTDefaults *getDefaults(NSString *appPath)
{
  NXTDefaults  *systemDefaults;
  id           serverCommand;
  NSString     *defaultsPath;
  NSDictionary *defaults;
  NSString     *bundlePath;

  if (loginDefaults != nil) {
    return loginDefaults;
  }
  
  systemDefaults = [NXTDefaults systemDefaults];
  serverCommand = [systemDefaults objectForKey:@"WindowServerCommand"];

  // User defaults is not correct
  if (serverCommand == nil ||
      [serverCommand isKindOfClass:[NSArray class]] == NO) {
    bundlePath = [appPath stringByDeletingLastPathComponent];
    defaultsPath = [bundlePath stringByAppendingPathComponent:@"Resources/Login"];
    defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];
    for (NSString *key in [defaults allKeys]) {
      [systemDefaults setObject:[defaults objectForKey:key] forKey:key];
    }
    [systemDefaults synchronize];
  }

  return systemDefaults;
}

//-----------------------------------------------------------------------------
// --- main()
//-----------------------------------------------------------------------------
int main(int argc, const char **argv)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSString          *startupHook;
  NSString          *shutdownHook;
  NSString          *exitCommand;
  int               gpbs_pid = 0;
  __block BOOL      isRunEventLoop = YES;

  panelExitCode = 0;
  
  // SIGQUIT will be received from systemd on `systemctl stop loginwindow`
  signal(SIGQUIT, handleSignal);

  // Defaults
  loginDefaults = getDefaults([NSString stringWithCString:argv[0]]);

  plymouthDeactivate();
  // Start Window Server
  XInitThreads();
  if (startWindowServer() == 0) {
    gpbs_pid = runCommand(@"/Library/bin/gpbs --daemon", NO);
    plymouthQuit(YES);

    // Setup layout and gamma.
    // Inital brightess was set to 0.0. Displays will be lighten in
    // [NSApp applicationDidFinishLaunching].
    // setupDisplays();

    //--- X11 event loop queue --------------------------------------------------
    x_q = dispatch_queue_create("ns.login.xeventloop", NULL);
    dispatch_sync(x_q, ^{ prepareEventLoop(); });
    dispatch_async(x_q, ^{
        XEvent event;
        
        while (isRunEventLoop != NO) {
          XNextEvent(dpy, &event); // blocks here
          if (event.type & RRScreenChangeNotifyMask) {
            // Handle screen change event
            printf("[EventLoop] RandR event received.\n");
            XRRUpdateConfiguration(&event);
          }
          else {
            printf("[EventLoop] some event received.\n");
          }
        }
        printf("[EventLoop] quit\n");
      });
    //---------------------------------------------------------------------------

    // StartupHook defined only system defaults (root user or app bundle)
    startupHook = [loginDefaults objectForKey:@"StartupHook"];
    if ([startupHook isEqualToString:@""] == NO) {
      if (runCommand(startupHook, YES) != 0) {
        NSLog(@"Warning: StartupHook run is not successful.");
      }
    }

    // Since there is no window manager running yet, we'll want to
    // do window decorations ourselves
    [[NSUserDefaults standardUserDefaults] setBool:NO 
                                            forKey:@"GSX11HandlesWindowDecorations"];
    setenv("FREETYPE_PROPERTIES", "truetype:interpreter-version=35", 1);
    // Start our application without appicon
    [LoginApplication sharedApplication];
    
    //--- Login application queue------------------------------------------------
    app_q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_sync(app_q, ^{
        NSApplicationMain(argc, argv);
      });
    //---------------------------------------------------------------------------
    // NSApplicationMain(argc, argv);

    isRunEventLoop = NO;
    XCloseDisplay(dpy);
    // sendMessage();
    // XFlush(dpy);
    // NSLog(@"Stopping EventLoop");
    // dispatch_sync(x_q, ^{ XCloseDisplay(dpy); });
    // NSLog(@"EventLoop stopped");

    // Stop Window Server
    if (xorgTask != nil) {
      NSLog(@"Terminating window server...");
      [xorgTask terminate];
    }
    // Stop Pasteboard Service
    if (gpbs_pid) {
      kill(gpbs_pid, SIGQUIT);
    }

    // Show shutdown Plymouth splash screen
    plymouthStart(1);
  }
  else {
    NSLog(@"Unable to start Login Panel: no Window Server available.");
  }

  // Panel stopped it's execution - check exit code
  switch (panelExitCode)
    {
    case QuitExitCode:
      NSLog(@"`quit` command: Just finish Login execution.");
      exitCommand = @"";
      break;
    case RebootExitCode:
      exitCommand = [loginDefaults objectForKey:@"RebootCommand"];
      if (exitCommand == nil || [exitCommand isEqualToString:@""]) {
        exitCommand = @"shutdown -r now";
      }
      NSLog(@"Reboot system with command: %@", exitCommand);
      break;
    case ShutdownExitCode:
      // ShutownHook defined only system defaults (root user or app bundle)
      shutdownHook = [loginDefaults objectForKey:@"ShutdownHook"];
      if ([shutdownHook isEqualToString:@""] == NO) {
        runCommand(shutdownHook, YES);
      }
      
      exitCommand = [loginDefaults objectForKey:@"ShutdownCommand"];
      if (exitCommand == nil || [exitCommand isEqualToString:@""]) {
        exitCommand = @"shutdown -h now";
      }
      NSLog(@"Shutdown system with command: %@", exitCommand);
      break;
    case UpdateExitCode:
      exitCommand = @"yum -y update";
      NSLog(@"TODO: System update will be performed. Show panel with progress.");
      break;
    default:
      NSLog(@"Unknown panel exit code received: %i", panelExitCode);
      exitCommand = @"";
    }

  NSLog(@"Exiting...");
  
  // Run exitCommand
  if (exitCommand && [exitCommand isEqualToString:@""] == NO) {
    runCommand(exitCommand, NO);
  }
  
  [pool release];

  return 0;
}
