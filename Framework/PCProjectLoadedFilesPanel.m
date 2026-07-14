/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2003-2004 Free Software Foundation

   Authors: Serg Stoyan

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

#import <ProjectCenter/PCProjectManager.h>
#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCProjectLoadedFiles.h>
#import <ProjectCenter/PCProjectLoadedFilesPanel.h>

#import <ProjectCenter/PCLogController.h>

#import "Modules/Preferences/Misc/PCMiscPrefs.h"

@implementation PCProjectLoadedFilesPanel

- (id)initWithProjectManager:(PCProjectManager *)aManager
{
  PCProject            *activeProject = nil;

  projectManager = aManager;
  activeProject = [projectManager rootActiveProject];
  currentProject = activeProject;

  PCLogStatus(self, @"[init]");

  self = [super initWithContentRect: NSMakeRect (0, 300, 220, 322)
                         styleMask: (NSTitledWindowMask 
		                    | NSClosableWindowMask
				    | NSResizableWindowMask)
			   backing: NSBackingStoreRetained
			     defer: YES];
//  [self setFloatingPanel:YES];
  [self setMinSize: NSMakeSize(120, 23)];
  [self setFrameAutosaveName: @"LoadedFiles"];
  [self setReleasedWhenClosed: NO];
  [self setHidesOnDeactivate: YES];
  [self setTitle: [NSString stringWithFormat: 
    @"%@ - Loaded Files", [activeProject projectName]]];

  // Panel's content view
  contentBox = [[NSBox alloc] init];
  [contentBox setContentViewMargins:NSMakeSize(0.0, 0.0)];
  [contentBox setTitlePosition:NSNoTitle];
  [contentBox setBorderType:NSNoBorder];
  [self setContentView:contentBox];

  // Empty content view of contentBox
  emptyBox = [[NSBox alloc] init];
  [emptyBox setContentViewMargins:NSMakeSize(0.0, 0.0)];
  [emptyBox setTitlePosition:NSNoTitle];
  [emptyBox setBorderType:NSLineBorder];
  [contentBox setContentView:emptyBox];

  // Track project switching
  [[NSNotificationCenter defaultCenter] 
    addObserver:self
       selector:@selector(activeProjectDidChange:)
           name:PCActiveProjectDidChangeNotification
         object:nil];

  if (![self setFrameUsingName: @"LoadedFiles"])
    {
      [self center];
    }

  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog(@"PCLoadedFilesPanel: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(contentBox);
  RELEASE(emptyBox);
  
  [super dealloc];
}

- (void)orderFront:(id)sender
{
  PCProject *activeProject = [projectManager rootActiveProject];
  NSView    *filesView = [[activeProject projectLoadedFiles] componentView];

  if (!([contentBox contentView] == filesView))
    {
      [contentBox setContentView:filesView];
      [contentBox display];
    }

  [super orderFront:self];
}

- (void)close
{
  [contentBox setContentView:emptyBox];

  [super close];
}

- (void)activeProjectDidChange:(NSNotification *)aNotif
{
  PCProject          *rootProject;
  id <PCPreferences> prefs = [projectManager prefController];

  if (![prefs boolForKey:UseTearOffWindows])
    {
      return;
    }

  rootProject = [projectManager rootActiveProject];
  if (rootProject == currentProject)
    {
      return;
    }

  currentProject = rootProject;
    
  if (!rootProject)
    {
      [contentBox setContentView:emptyBox];
    }
  else
    {
      [self setTitle: [NSString stringWithFormat: 
	@"%@ - Loaded Files", [rootProject projectName]]];
      [contentBox 
	setContentView:[[rootProject projectLoadedFiles] componentView]];
    }
}

@end

