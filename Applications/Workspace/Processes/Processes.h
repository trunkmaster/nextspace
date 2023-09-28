/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description: "Processes" panel controller.
// Processes (controller of "Processes" panel):
// - initialized on panel creation (firsr click on Tools->Processes... menu
//   item);
// - provide and manage "Processes" panel;
// - provide GUI to display and manage running applications;
// - provide GUI (progress, alert) for background operations;
// - information about running applications and background processes requested
//   from ProcessManager (see above);
//
// Copyright (C) 2018 Sergii Stoian
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
  id appList;  // should be procList: shared table for Apps and BGProcessess
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
