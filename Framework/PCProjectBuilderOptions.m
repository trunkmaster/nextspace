/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2007 Free Software Foundation

   Authors: Philippe C.D. Robert
            Sergii Stoian

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

#import <ProjectCenter/PCProjectBuilderOptions.h>

#import <ProjectCenter/PCDefines.h>
#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCLogController.h>

@implementation PCProjectBuilderOptions

- (void)_setStateForButton:(id)button 
		       key:(NSString *)key
	      defaultState:(int)dState
{
  NSString *value = [[project projectDict] objectForKey:key];
  int      state;

  if (value == nil)
    {
      state = dState;
    }
  else
    {
      if ([value isEqualToString:@"YES"])
	state = NSOnState;
      else
	state = NSOffState;
    }
  [button setState:state];
}

- (id)initWithProject:(PCProject *)aProject delegate:(id)aDelegate
{
  if ((self = [super init]))
    {
      project = aProject;
      delegate = aDelegate;

      [[NSNotificationCenter defaultCenter]
	addObserver:self
	   selector:@selector(loadProjectProperties:)
	       name:PCProjectDictDidChangeNotification
	     object:nil];
    }

  return self;
}

- (void)dealloc
{
#ifdef DEBUG
  NSLog (@"PCProjectBuilderOptions: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [super dealloc];
}

- (void)awakeFromNib
{
  [verboseButton setRefusesFirstResponder:YES];
  [debugButton setRefusesFirstResponder:YES];
  [stripButton setRefusesFirstResponder:YES];
  [sharedLibsButton setRefusesFirstResponder:YES];

  [self loadProjectProperties:nil];
}

- (void)show:(NSRect)builderRect
{
  NSRect opRect;

  if (!optionsPanel)
    {
      if ([NSBundle loadNibNamed:@"BuilderOptions" owner:self] == NO)
	{
	  PCLogError(self, @"error loading BuilderOptions NIB file!");
	  return;
	}

    }

  opRect = [optionsPanel frame];
  opRect.origin.x = builderRect.origin.x + 
    (builderRect.size.width - opRect.size.width)/2;
  opRect.origin.y = builderRect.origin.y + 
    (builderRect.size.height - opRect.size.height)/2;
  [optionsPanel setFrame:opRect display:NO];

  [optionsPanel makeKeyAndOrderFront:nil];
  [optionsPanel makeFirstResponder:buildArgsField];
}

- (NSString *)buildTarget
{
  if (targetPopup)
    {
      return [targetPopup titleOfSelectedItem];
    }

  return nil;
}

- (void)optionsPopupChanged:(id)sender
{
  [delegate targetDidSet:[targetPopup titleOfSelectedItem]];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotif
{
  id             object = [aNotif object];
  NSMutableArray *args;

  if (object != buildArgsField)
    return;

  args = [[[buildArgsField stringValue] componentsSeparatedByString:@" "]
    mutableCopy];
  [args removeObject:@""];
  [args removeObject:@" "];

  [project setProjectDictObject:args forKey:PCBuilderArguments notify:NO];

  [delegate targetDidSet:[targetPopup titleOfSelectedItem]];
}

- (void)optionsButtonClicked:(id)sender
{
  NSString *value = [sender state] == NSOnState ? @"YES" : @"NO";
  NSString *key;

  if (sender == verboseButton)
      key = PCBuilderVerbose;
  if (sender == debugButton)
      key = PCBuilderDebug;
  if (sender == stripButton)
    key = PCBuilderStrip;
  if (sender == sharedLibsButton)
    key = PCBuilderSharedLibs;

  [project setProjectDictObject:value forKey:key notify:NO];
}

- (void)loadProjectProperties:(NSNotification *)aNotif
{
  NSArray *args;

  // Setup target popup
  [targetPopup removeAllItems];
  [targetPopup addItemsWithTitles:[project buildTargets]];
  [targetPopup selectItemAtIndex:0];

  // Setup build arguments field
  args = [[project projectDict] objectForKey:PCBuilderArguments];
  [buildArgsField setStringValue:[args componentsJoinedByString:@" "]];

  // Setup option buttons
  [self _setStateForButton:verboseButton
		       key:PCBuilderVerbose
	      defaultState:NSOffState];
  [self _setStateForButton:debugButton
		       key:PCBuilderDebug
	      defaultState:NSOnState];
  [self _setStateForButton:stripButton
		       key:PCBuilderStrip
	      defaultState:NSOffState];
  [self _setStateForButton:sharedLibsButton
		       key:PCBuilderSharedLibs
	      defaultState:NSOnState];
}

@end
