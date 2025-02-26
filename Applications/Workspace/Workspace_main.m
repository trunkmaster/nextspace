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

#import <CoreFoundation/CFRunLoop.h>
#import <AppKit/AppKit.h>

#import <SystemKit/OSEScreen.h>
#import <SystemKit/OSEDefaults.h>

#import "Application.h"
#import "Recycler.h"
#import "Workspace+WM.h"

#include "WM/wmcomposer.h"

// Global - set in WM/event.c - WMRunLoop()
CFRunLoopRef wm_runloop = NULL;

//-----------------------------------------------------------------------------
// Workspace X Window related utility functions
//-----------------------------------------------------------------------------

static BOOL _isWindowServerReady(void)
{
  Display *xdpy = XOpenDisplay(NULL);
  BOOL ready = (xdpy == NULL ? NO : YES);

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
  Display *xDisplay = NULL;
  int xScreen = -1;
  long event_mask;
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
  } else {
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

void WSUncaughtExceptionHandler(NSException *e)
{
  NSLog(@"*** EXCEPTION *** NAME: %@ REASON: %@", [e name], [e reason]);
}

int WSApplicationMain(int argc, const char **argv)
{
  NSDictionary *infoDict;
  NSString *mainModelFile;

  CREATE_AUTORELEASE_POOL(pool);

  infoDict = [[NSBundle mainBundle] infoDictionary];

  [WSApplication sharedApplication];

  mainModelFile = [infoDict objectForKey:@"NSMainNibFile"];
  if (mainModelFile != nil && [mainModelFile isEqual:@""] == NO) {
    if ([NSBundle loadNibNamed:mainModelFile owner:NSApp] == NO) {
      NSLog(_(@"Cannot load the main model file '%@'"), mainModelFile);
    }
  }

  RECREATE_AUTORELEASE_POOL(pool);

  wSetErrorHandler();

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
    fprintf(stderr, "[Workspace] Error: other window manager already running. Quitting...\n");
    exit(1);
  }

  fprintf(stderr, "=== Starting Workspace ===\n");
  workspace_q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
  dispatch_sync(workspace_q, ^{
    @autoreleasepool {
      // Restore display layout
      OSEScreen *screen = [OSEScreen sharedScreen];
      [screen applySavedDisplayLayout];
    }
  });
  {
    // DISPATCH_QUEUE_CONCURRENT is mandatory for CFRunLoop run.
    dispatch_queue_t window_manager_q = dispatch_queue_create("ns.workspace.wm",
                                                              DISPATCH_QUEUE_CONCURRENT);

    //--- Initialize Window Manager
    fprintf(stderr, "=== Initializing Window Manager ===\n");
    dispatch_sync(window_manager_q, ^{
      wInitialize(argc, (char **)argv);
      wStartUp(True);

      WSUpdateScreenInfo(wDefaultScreen());
    });
    fprintf(stderr, "=== Window Manager initialized! ===\n");

    //--- Composer
    OSEDefaults *defs = [[OSEDefaults alloc] initDefaultsWithPath:NSUserDomainMask
                                                           domain:@"Workspace"];
    if ([defs boolForKey:@"ComposerEnabled"] != NO) {
      dispatch_queue_t composer_q = dispatch_queue_create("ns.workspace.composer", DISPATCH_QUEUE_CONCURRENT);
      dispatch_async(composer_q, ^{
        fprintf(stderr, "=== Initializing Composer ===\n");
        if (wComposerInitialize() == True) {
          fprintf(stderr, "=== Composer initialized ===\n");
          wComposerRunLoop();
          fprintf(stderr, "=== Composer completed it's execution ===\n");
        } else {
          fprintf(stderr, "=== Failed to initialize Composer ===\n");
        }
      });
    }
    [defs release];

    // Start WM run loop V0 to catch events while V1 is warming up.
    dispatch_async(window_manager_q, ^{
      WMRunLoop_V0();
    });
    dispatch_async(window_manager_q, ^{
      WMRunLoop_V1();
    });
  }

  //--- Workspace (GNUstep) queue ---------------------------------------
  fprintf(stderr, "=== Workspace initialized! ===\n");
  dispatch_sync(workspace_q, ^{
    NSSetUncaughtExceptionHandler(WSUncaughtExceptionHandler);
    WSApplicationMain(argc, argv);
  });
  fprintf(stderr, "=== Workspace finished with exit code: %i ===\n", ws_quit_code);

  wShutdown(WMExitMode);
  fprintf(stderr, "=== Window Manager execution has been stopped ===\n");

  return ws_quit_code;
}
