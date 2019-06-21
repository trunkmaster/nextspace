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

#import <unistd.h>
#import <sys/wait.h>
#import <X11/Xlib.h>
#import <X11/cursorfont.h>
#import <X11/Xcursor/Xcursor.h>

#import <AppKit/NSApplication.h>
#import <DesktopKit/NXTDefaults.h>
#import <SystemKit/OSEScreen.h>
#import <SystemKit/OSEDisplay.h>

#import "Application.h"
#import "Controller.h"
#import "Login_main.h"

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

// Returns PID of running command if `wait` == NO
// Returns exit status of child process if `wait` == YES
int runCommand(NSString *command, BOOL wait)
{
  NSArray    *commandArgs;
  const char **argv;
  int        argc, pid = 0, child_status;

  commandArgs = [command componentsSeparatedByString:@" "];
  argc = [commandArgs count];
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

//-----------------------------------------------------------------------------
// --- Misc ---
//-----------------------------------------------------------------------------
static void handleSignal(int sig)
{
  fprintf(stderr, "[Login] got signal %i\n", sig);
  [NSApp stop:nil];
}

NXTDefaults *getDefaults(NSString *appPath)
{
  NXTDefaults  *userDefaults;
  id           serverCommand;
  NSString     *defaultsPath;
  NSDictionary *defaults;
  NSString     *bundlePath;

  if (loginDefaults != nil) {
    return loginDefaults;
  }
  
  userDefaults = [NXTDefaults userDefaults];
  serverCommand = [userDefaults objectForKey:@"WindowServerCommand"];

  // User defaults is not correct
  if (serverCommand == nil ||
      [serverCommand isKindOfClass:[NSArray class]] == NO) {
    bundlePath = [appPath stringByDeletingLastPathComponent];
    defaultsPath = [bundlePath stringByAppendingPathComponent:@"Resources/Login"];
    defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];
    for (NSString *key in [defaults allKeys]) {
      [userDefaults setObject:[defaults objectForKey:key] forKey:key];
    }
    [userDefaults synchronize];
  }

  return userDefaults;
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

  panelExitCode = 0;
  
  // SIGQUIT will be received from systemd on `systemctl stop loginwindow`
  signal(SIGQUIT, handleSignal);

  // Defaults
  loginDefaults = getDefaults([NSString stringWithCString:argv[0]]);

  plymouthDeactivate();
  // Start Window Server
  if (startWindowServer() == 0) {
    gpbs_pid = runCommand(@"/Library/bin/gpbs --daemon", NO);
    plymouthQuit(YES);

    // Setup layout and gamma.
    // Inital brightess was set to 0.0. Displays will be lighten in
    // [NSApp applicationDidFinishLaunching].
    // setupDisplays();
      
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
    // Run loop
    NSApplicationMain(argc, argv);

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
