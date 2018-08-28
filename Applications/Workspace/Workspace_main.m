/*
   Copyright (C) 2011 Sergii Stoian

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <AppKit/AppKit.h>
#import <NXSystem/NXScreen.h>

#import "Workspace+WindowMaker.h"

int main(int argc, const char **argv)
{
  if (xIsWindowServerReady() == NO)
    {
      fprintf(stderr, "[Workspace] X Window server is not ready on display '%s'\n", getenv("DISPLAY"));
      exit(1);
    }
  
#ifdef NEXTSPACE
  useInternalWindowManager = !xIsWindowManagerAlreadyRunning();
  if (useInternalWindowManager)
    {
      fprintf(stderr,"[Workspace] === Starting Workspace Manager [%s]... ===\n", REVISION);

      workspace_q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
      wmaker_q = dispatch_queue_create("ns.workspace.windowmaker", NULL);

      fprintf(stderr, "[Workspace] === Initializing WindowMaker... ===\n");
      //--- WindowMaker queue -----------------------------------------------
      dispatch_sync(wmaker_q,
                    ^{
                      NSLog(@"WindowMaker thread: %@ (main: %@)",
                            [NSThread currentThread], [NSThread mainThread]);
                      WWMInitializeWindowMaker(argc, (char **)argv);
                    });
      fprintf(stderr, "[Workspace] === WindowMaker initialized! ===\n");

      // Start X11 EventLoop in parallel
      dispatch_async(wmaker_q, ^{ EventLoop(); });
      
      fprintf(stderr, "[Workspace] === Starting Workspace application... ===\n");
      //--- Workspace (GNUstep) queue ---------------------------------------
      dispatch_sync(workspace_q,
                    ^{
                      @autoreleasepool
                        {
                          NSLog(@"Workspace thread: %@ (main: %@)",
                                [NSThread currentThread], [NSThread mainThread]);
                          NSApplicationMain(argc, argv);
                          NSLog(@"Workspace applicaton terminated.");
                        }
                    });
      //---------------------------------------------------------------------
    }
  else
#endif // NEXTSPACE
    {
      @autoreleasepool
        {
          NSLog(@"Starting Workspace as standalone application!");
          NSApplicationMain(argc, argv);
        }
    }
  
  return 0;
}
