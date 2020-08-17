/* -*- mode: objc -*- */
//
// Project: Workspace
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

#import <AppKit/AppKit.h>

#import "Workspace+WM.h"

//-----------------------------------------------------------------------------
// Workspace X Window related utility functions
//-----------------------------------------------------------------------------

static BOOL _isWindowServerReady(void)
{
  Display *xdpy = XOpenDisplay(NULL);
  BOOL    ready = (xdpy == NULL ? NO : YES);

  if (ready) {
    XCloseDisplay(xdpy);
  }

  return ready;
}

static int CantManageScreen = 0;
static int _wmRunningErrorHandler(Display *dpy, XErrorEvent *error)
{
  CantManageScreen = 1;
  return -1;
}

static BOOL _isWindowManagerRunning(void)
{
  Display       *xDisplay = NULL;
  int           xScreen = -1;
  long          event_mask;
  XErrorHandler oldHandler;

  oldHandler = XSetErrorHandler((XErrorHandler)_wmRunningErrorHandler);
  event_mask = SubstructureRedirectMask;

  xDisplay = XOpenDisplay(NULL);
  xScreen = DefaultScreen(xDisplay);
  XSelectInput(xDisplay, RootWindow(xDisplay, xScreen), event_mask);

  XSync(xDisplay, False);
  XSetErrorHandler(oldHandler);

  if (CantManageScreen) {
    XCloseDisplay(xDisplay);
    return YES;
  }
  else {
    event_mask &= ~(SubstructureRedirectMask);
    XSelectInput(xDisplay, RootWindow(xDisplay, xScreen), event_mask);
    XSync(xDisplay, False);
    XCloseDisplay(xDisplay);
    return NO;
  }
}

//-----------------------------------------------------------------------------
// Workspace application GNUstep main function
//-----------------------------------------------------------------------------

// WM/src/startup.c
extern void WMSetErrorHandler(void);

int WSApplicationMain(int argc, const char **argv)
{
  NSDictionary		*infoDict;
  NSString              *mainModelFile;
  NSString		*className;
  Class			appClass;
  
  CREATE_AUTORELEASE_POOL(pool);

  infoDict = [[NSBundle mainBundle] infoDictionary];
  className = [infoDict objectForKey:@"NSPrincipalClass"];
  appClass = NSClassFromString(className);

  if (appClass == 0) {
    NSLog(@"Bad application class '%@' specified", className);
    appClass = [NSApplication class];
  }
  [appClass sharedApplication];

  mainModelFile = [infoDict objectForKey:@"NSMainNibFile"];
  if (mainModelFile != nil && [mainModelFile isEqual: @""] == NO) {
    if ([NSBundle loadNibNamed: mainModelFile owner: NSApp] == NO) {
      NSLog (_(@"Cannot load the main model file '%@'"), mainModelFile);
    }
  }

  RECREATE_AUTORELEASE_POOL(pool);

  WMSetErrorHandler();

  [NSApp run];

  [pool drain];

  return 0;
}

int main(int argc, const char **argv)
{
  if (_isWindowServerReady() == NO) {
    fprintf(stderr, "[Workspace] X Window server is not ready on display '%s'\n",
            getenv("DISPLAY"));
    exit(1);
  }

  if (_isWindowManagerRunning() == YES) {
    fprintf(stderr,
            "[Workspace] Error: other window manager already running. Quitting...\n");
    exit(1);    
  }
  
  fprintf(stderr,"=== Starting Workspace [%s]... ===\n", REVISION);
  workspace_q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
  wmaker_q = dispatch_queue_create("ns.workspace.wm", NULL);

  //--- WindowMaker queue -----------------------------------------------
  fprintf(stderr, "=== Initializing Window Manager... ===\n");
  dispatch_sync(wmaker_q, ^{
      WMInitializeWindowMaker(argc, (char **)argv);
    });
  fprintf(stderr, "=== Window Manager initialized! ===\n");

  // Start X11 EventLoop in parallel
  dispatch_async(wmaker_q, ^{ EventLoop(); });
      
  //--- Workspace (GNUstep) queue ---------------------------------------
  fprintf(stderr, "=== Starting the Workspace... ===\n");
  dispatch_sync(workspace_q, ^{
      @autoreleasepool {
        WSApplicationMain(argc, argv);
      }
    });
  fprintf(stderr, "=== Workspace successfully finished! ===\n");
  //---------------------------------------------------------------------
  
  fprintf(stderr, "=== Quitting Window manager... ===\n");
  // Quit WindowManager, close all X11 applications.
  WMShutdown(WSKillMode);
  
  fprintf(stderr, "=== Exit code is %i ===\n", ws_quit_code);
  return ws_quit_code;
}
