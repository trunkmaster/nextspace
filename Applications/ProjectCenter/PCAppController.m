/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2021 Free Software Foundation

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <ProjectCenter/PCLogController.h>
#import <ProjectCenter/PCFileManager.h>

#import "PCAppController.h"
#import "PCMenuController.h"
#import "PCInfoController.h"
#import "PCPrefController.h"

#import "Modules/Preferences/Build/PCBuildPrefs.h"
#import "Modules/Preferences/Saving/PCSavingPrefs.h"
#import "Modules/Preferences/Misc/PCMiscPrefs.h"

#import <ProjectCenter/ProjectCenter.h>

@implementation PCAppController

//============================================================================
//==== Intialization & deallocation
//============================================================================

+ (void)initialize
{
}

- (id)init
{
  if ((self = [super init]))
    {
      infoController = [[PCInfoController alloc] init];
      // Temporary workaround to initialize defaults values
      prefController = [PCPrefController sharedPCPreferences];
      logController  = [PCLogController sharedLogController];

      // It's our entry point to Framework
      projectManager = [[PCProjectManager alloc] init];
      [projectManager setDelegate:self];
      [projectManager setPrefController:prefController];
    }

  return self;
}

- (void)dealloc
{
  RELEASE(infoController);
  RELEASE(projectManager);
  [super dealloc];
}

- (void)awakeFromNib
{
  [menuController setAppController:self];
  [menuController setProjectManager:projectManager];
}

//============================================================================
//==== Accessory methods
//============================================================================

- (PCProjectManager *)projectManager
{
  return projectManager;
}

- (PCMenuController *)menuController
{
  return menuController;
}

- (PCInfoController *)infoController
{
  return infoController;
}

- (PCPrefController *)prefController
{
  return prefController;
}

- (PCLogController *)logController
{
  return logController;
}

//============================================================================
//==== Misc...
//============================================================================

- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName
{
  [NSApp activateIgnoringOtherApps:YES];

  if (![fileName isAbsolutePath])
    {
      NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
      fileName = [cwd stringByAppendingPathComponent: fileName];
    }

  if ([[fileName pathExtension] isEqualToString:@"pcproj"] == YES
      || [[fileName pathExtension] isEqualToString:@"project"] == YES) 
    {
      [projectManager openProjectAt: fileName makeActive: YES];
    }
  else
    {
      [projectManager openFileAtPath:fileName];
    }

  return YES;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  if ([prefController boolForKey:DisplayLog])
    {
      [logController showPanel];
    }

  [logController 
    logMessage:NSLocalizedString(@"Loading additional subsystems...", @"When loaded additional bundles") withTag:INFO sender:self];

  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCAppDidInitNotification
                  object:nil];

  if (NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) ==
      NSWindows95InterfaceStyle)
    {
      NSFileManager *fm = [NSFileManager defaultManager];
      NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:
					 @"PCExample"];

      if ([fm fileExistsAtPath: path])
	{
	  [projectManager openProjectAt: path makeActive: YES];
	}
      else
	{
	  PCProject *project;

	  project = [projectManager createProjectOfType: @"Application"
			   path: [NSHomeDirectory() stringByAppendingPathComponent: @"PCExample"]];

	  [[projectManager loadedProjects] setObject: project
					      forKey: [project projectPath]];
	  [projectManager setActiveProject:project];
	  [[project projectWindow] orderFront: self];
	}
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(id)sender
{
  NSApplicationTerminateReply quit = NSTerminateNow;

  if ([prefController boolForKey:PromptOnQuit] &&
      NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) !=
      NSWindows95InterfaceStyle)
    {
      if (NSRunAlertPanel(@"Quit",
			  @"Do you really want to quit ProjectCenter?",
			  @"Cancel", @"Quit", nil))
	{
	  return NSTerminateLater;
	}

    }

  // Save projects unconditionally if preferences tells that
  if ([prefController boolForKey:SaveOnQuit])
    {
      if(![projectManager saveAllProjects])
        quit = NSTerminateLater;
    }

  // Close ProjectManager (projects, editors, etc.)
  if ((quit == NO) || ([projectManager close] == NO))
    {
      return NSTerminateLater;
    }

  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCAppWillTerminateNotification
                  object:nil];

  return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
  NSFileManager *fm;
  PCFileManager *pcfm;
  NSString      *rootBuildDir;
  NSArray       *rootBuildDirList;
  NSEnumerator  *enumerator;
  NSString      *buildItem;

#ifdef DEBUG
  NSLog(@"--- Application WILL terminate");
#endif

  if ([prefController boolForKey:DeleteCacheWhenQuitting]) 
    {
      fm = [NSFileManager defaultManager];
      pcfm = [PCFileManager defaultManager];

      rootBuildDir = [prefController stringForKey:RootBuildDirectory];
      rootBuildDirList = [fm directoryContentsAtPath:rootBuildDir];

      enumerator = [rootBuildDirList objectEnumerator];
      while ((buildItem = [enumerator nextObject]))
	{
	  if([[buildItem pathExtension] isEqualToString:@"build"])
	    {
	      NSLog(@"Remove build directory %@/%@",
		    rootBuildDir, buildItem);
	      [pcfm removeFile:buildItem
		 fromDirectory:rootBuildDir removeDirsIfEmpty:YES];
	    }
	}

    }

  //--- Cleanup
  if (doConnection)
    {
      [doConnection invalidate];
      RELEASE(doConnection);
    }

  if (NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) ==
      NSWindows95InterfaceStyle)
    {
      NSFileManager *fm = [NSFileManager defaultManager];
      NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:
					 @"PCExample"];

      if ([fm fileExistsAtPath: path])
	{
	  [fm removeFileAtPath: path handler: nil];
	}
    }

  RELEASE(infoController);
  RELEASE(prefController);
  RELEASE(logController);
  RELEASE(menuController);
  RELEASE(projectManager);

#ifdef DEBUG
  NSLog (@"--- Application WILL terminate.END");
#endif
}

@end

