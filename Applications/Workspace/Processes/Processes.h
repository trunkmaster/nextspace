/*
   Processes.h
   "Processes" panel controller.
   
   Copyright (C) 2015 Sergii Stoian

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

// Processes (controller of "Processes" panel):
// - initialized on panel creation (firsr click on Tools->Processes... menu
//   item);
// - provide and manage "Processes" panel;
// - provide GUI to display and manage running applications;
// - provide GUI (progress, alert) for background operations;
// - information about running applications and background processes requested
//   from ProcessManager (see above);

#import <Foundation/Foundation.h>

#import <Operations/ProcessManager.h>

@interface Processes : NSObject
{
  ProcessManager *manager;
  
  int displayedFop;

  // Process.nib
  id procWindow;
  id procPopup;
  id procBox;
  //  id procList; // applications or background processes

  // AppProcessUI.nib
  id appBogusWindow;
  id appBox;
  id appList; // should be procList: shared table for Apps and BGProcessess
  id appIcon;
  id appKillBtn;
  id appName;
  id appPID;
  id appPath;
  id appStatus;

  // CPMVProcess.nib
  id backBogusWindow;
  id backBox;
  id backList;
  id backFopBox;
  id backNoFopLabel;
}

+ shared;

- initWithManager:(ProcessManager *)procman;
- (void)dealloc;
- (NSWindow *)window;

- (void)show;
- (void)setView:(id)sender;

@end

@interface Processes (Applications)

- (void)showApp:(id)sender;
- (void)activateApp:sender;
- (void)updateAppList;

@end

@interface Processes (Background)

- (void)showOperation:(id)sender;
- (void)updateBGProcessList;

@end

