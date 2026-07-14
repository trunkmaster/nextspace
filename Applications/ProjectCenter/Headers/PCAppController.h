/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2012 Free Software Foundation
   
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

#ifndef _PCAPPCONTROLLER_H
#define _PCAPPCONTROLLER_H

#import <AppKit/AppKit.h>

@class PCProjectManager;
@class PCFileManager;
@class PCMenuController;
@class PCInfoController;
@class PCPrefController;
@class PCLogController;

@interface PCAppController : NSObject
{
  PCProjectManager *projectManager;
  PCMenuController *menuController;
  
  PCInfoController *infoController;
  PCPrefController *prefController;
  PCLogController  *logController;

  NSConnection     *doConnection;
}

//============================================================================
//==== Intialization & deallocation
//============================================================================

+ (void)initialize;

- (id)init;
- (void)dealloc;

//============================================================================
//==== Accessory methods
//============================================================================

- (PCProjectManager *)projectManager;
- (PCMenuController *)menuController;
- (PCInfoController *)infoController;
- (PCPrefController *)prefController;
- (PCLogController *)logController;

//============================================================================
//==== Application
//============================================================================

- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName;

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;

- (NSApplicationTerminateReply)applicationShouldTerminate:(id)sender;
- (void)applicationWillTerminate:(NSNotification *)notification;

@end

#endif
