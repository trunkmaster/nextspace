/*
   main.m
   The main function of the Login application.

   This file is part of xSTEP.

   Copyright (C) 2005 Serg Stoyan

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

#include <X11/Xlib.h>
#import <unistd.h>

#import <AppKit/NSApplication.h>
#import <NXFoundation/NXDefaults.h>
#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>

#import "Application.h"
#import "Controller.h"

NSTask     *xorgTask = nil;
NXDefaults *loginDefaults = nil;

// --- Plymouth ---
BOOL isPlymouthRunning()
{
  int res = system("/usr/bin/plymouth --ping");

  return (res == 0) ? YES : NO;
}

void plymouthDeactivate()
{
  if (isPlymouthRunning() == YES)
    {
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

// --- X11 ---
int startWindowServer()
{
  NSMutableArray *serverArgs;
  NSString       *server;
  Display        *xDisplay = NULL;

  setenv("DISPLAY", ":0.0", 0);
  setenv("HOME", "/root", 1);
  setenv("USER", "root", 0);

  // NSLog(@"DISPLAY = %s", getenv("DISPLAY"));
  // NSLog(@"HOME = %s", getenv("HOME"));
  // NSLog(@"USER = %s", getenv("USER"));

  if ((xDisplay = XOpenDisplay(NULL)) == NULL)
    {
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
      while (xDisplay == NULL)
	{
	  xDisplay = XOpenDisplay(NULL); // NULL == getenv("DISPLAY")
	}
      NSLog(@"================> Xorg is ready <================");
      XCloseDisplay(xDisplay);
    }

  return 0;
}

void setupDisplays()
{
  NXScreen  *screen = [NXScreen sharedScreen];
  NSArray   *layout;
  // NSArray   *systemDisplays;

  // Get layout with monitors aligned horizontally
  layout = [screen defaultLayout:YES];

  // Setup initial gamma and brightness
  // And check main display from saved layout is active
  // systemDisplays = [screen activeDisplays];
  // for (NXDisplay *display in systemDisplays)
  //   {
  //     [display setGammaBrightness:0.0];
  //   }
  // [systemDisplays release];
  
  [screen applyDisplayLayout:layout];
}

void startPasteboardService()
{
  const char *args[3];
  int        pid = 0;

  args[0] = "/Library/bin/gpbs";
  args[1] = "--daemon";
  args[2] = NULL;
  
  pid = fork();
  switch (pid)
    {
    case 0:
      execv("/Library/bin/gpbs", (char**)args);
      abort();
      break;
    default:
      break;
    }
}

int main(int argc, const char ** argv)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  // Defaults
  loginDefaults = [NXDefaults userDefaults];
  if (![[loginDefaults objectForKey:@"WindowServerCommand"]
         isKindOfClass:[NSArray class]])
    {
      NSString     *defsPath;
      NSDictionary *defs;
      defsPath = [[[NSString stringWithCString:argv[0]] stringByDeletingLastPathComponent]
                   stringByAppendingPathComponent:@"Resources/Login"];
      defs = [NSDictionary dictionaryWithContentsOfFile:defsPath];
      for (NSString *key in [defs allKeys])
        {
          [loginDefaults setObject:[defs objectForKey:key] forKey:key];
        }
      [loginDefaults synchronize];
    }

  plymouthDeactivate();

  // Start Window Server (Xorg)
  if (!startWindowServer())
    {
      system("xrdb -merge /etc/X11/Xresources.nextspace");
      startPasteboardService();
      plymouthQuit(YES);
      // Setup layout and gamma.
      // Inital brightess was set to 0.0. Displays will be lighten in
      // [NSApp applicationDidFinishLaunching].
      setupDisplays();
      
      // TODO: StartupHook
      NSString *startupHook = [loginDefaults objectForKey:@"StartupHook"];
      if (![startupHook isEqualToString:@""])
        {
          system([startupHook cString]);
        }

      // Since there is no window manager running yet, we'll want to
      // do window decorations ourselves
      [[NSUserDefaults standardUserDefaults] 
        setBool:NO 
         forKey:@"GSX11HandlesWindowDecorations"];

      // Start our application without appicon
      [LoginApplication sharedApplication];
      
      // Run loop
      NSApplicationMain(argc, argv);
    }

  if (xorgTask != nil)
    {
      NSLog(@"Terminating window server...");
      [xorgTask terminate];
    }

  [pool release];

  NSLog(@"Exiting...");
  return 0;
}
