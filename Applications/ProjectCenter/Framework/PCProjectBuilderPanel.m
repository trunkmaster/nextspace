/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2003 Free Software Foundation

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
#import <ProjectCenter/PCProjectBuilder.h>
#import <ProjectCenter/PCProjectBuilderPanel.h>

#import <ProjectCenter/PCLogController.h>

#import "Modules/Preferences/Misc/PCMiscPrefs.h"

@implementation PCProjectBuilderPanel

- (void)awakeFromNib
{
  PCProject *activeProject = [projectManager rootActiveProject];

  [panel setFrameAutosaveName:@"ProjectBuilder"];
  [panel setTitle:[NSString stringWithFormat: 
    @"%@ - Project Build", [activeProject projectName]]];

  // Panel's content view
  [panel setContentView:contentBox];

  // Empty content view of contentBox
  RETAIN(emptyBox);

  // Track project switching
  [[NSNotificationCenter defaultCenter] 
    addObserver:self
       selector:@selector(activeProjectDidChange:)
           name:PCActiveProjectDidChangeNotification
         object:nil];

  if (![panel setFrameUsingName:@"ProjectBuilder"])
    {
      [panel center];
    }
}

- (id)initWithProjectManager:(PCProjectManager *)aManager
{
  projectManager = aManager;

  if ([NSBundle loadNibNamed:@"BuilderPanel" owner:self] == NO)
    {
      PCLogError(self, @"error loading BuilderPanel NIB file!");
      return nil;
    }

  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog(@"PCBuildPanel: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  RELEASE(emptyBox);

  [super dealloc];
}

- (void)orderFront:(id)sender
{
  PCProject *activeProject = [projectManager rootActiveProject];
  NSView    *builderView = [[activeProject projectBuilder] componentView];

  if (!([contentBox contentView] == builderView))
    {
      [contentBox setContentView:builderView];
    }

/*  NSLog(self, @"orderFront: %@ -> %@", 
  	builderView, [builderView superview]);*/

  [panel orderFront:self];
}

- (void)close
{
//  PCLogInfo(self, @"close: %@", [contentBox contentView]);

  [contentBox setContentView:emptyBox];
  
//  PCLogInfo(self, @"close: %@", [contentBox contentView]);

  [panel close];
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

//  NSLog(@"Buider Panel: activeProjectDidChange to: %@",
//	[rootProject projectName]);

  if (!rootProject)
    {
      [contentBox setContentView:emptyBox];
    }
  else
    {
      [panel setTitle:[NSString stringWithFormat: 
	@"%@ - Project Build", [rootProject projectName]]];
      [contentBox setContentView:[[rootProject projectBuilder] componentView]];
    }
}

- (BOOL)isVisible
{
  return [panel isVisible];
}

// --- Panel delgate
- (BOOL)windowShouldClose:(id)sender
{
  [contentBox setContentView:emptyBox];
  return YES;
}

@end

