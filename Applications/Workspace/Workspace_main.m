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
#import <SystemKit/OSEScreen.h>

#import "Workspace+WM.h"

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
  if (xIsWindowServerReady() == NO) {
    fprintf(stderr, "[Workspace] X Window server is not ready on display '%s'\n",
            getenv("DISPLAY"));
    exit(1);
  }
  
#ifdef NEXTSPACE
  useInternalWindowManager = !xIsWindowManagerAlreadyRunning();
  if (useInternalWindowManager)
    {
      fprintf(stderr,"=== Starting Workspace [%s]... ===\n", REVISION);

      workspace_q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
      wmaker_q = dispatch_queue_create("ns.workspace.wm", NULL);

      fprintf(stderr, "=== Initializing Window Manager... ===\n");
      //--- WindowMaker queue -----------------------------------------------
      dispatch_sync(wmaker_q, ^{
          WWMInitializeWindowMaker(argc, (char **)argv);
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
      WWMShutdown(WSKillMode);
    }
  else
#endif // NEXTSPACE
    {
      @autoreleasepool {
        NSLog(@"Starting the Workspace as standalone application!");
        NSApplicationMain(argc, argv);
      }
    }
  
  fprintf(stderr, "=== Exit code is %i ===\n", ws_quit_code);
  return ws_quit_code;
}
