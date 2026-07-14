// 
// GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html
//
// Copyright (C) 2001-2009 Free Software Foundation
//
// Authors: Sergii Stoian
//
// Description: 
//
// This file is part of GNUstep.
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published 
// by the Free Software Foundation; either version 2 of the License, or 
// (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free Software 
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

#import <ProjectCenter/PCFileManager.h>

#import "PCBuildPrefs.h"

@implementation PCBuildPrefs

// ----------------------------------------------------------------------------
// --- Init and free
// ----------------------------------------------------------------------------

- (id)initWithPrefController:(id <PCPreferences>)aPrefs
{
  self = [super init];

  if ([NSBundle loadNibNamed:@"BuildPrefs" owner:self] == NO)
    {
      NSLog(@"PCBuildPrefs: error loading NIB file!");
    }

  prefs = aPrefs;

  RETAIN(buildingView);

  return self;
}

- (void)awakeFromNib
{
  [setSuccessButton setRefusesFirstResponder:YES];
  [setFailureButton setRefusesFirstResponder:YES];

  [setRootBuildDirButton setRefusesFirstResponder:YES];
  [setBuildToolButton setRefusesFirstResponder:YES];

  [deleteCache setRefusesFirstResponder:YES];
  [promptOnClean setRefusesFirstResponder:YES];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(buildingView);

  [super dealloc];
}


// Protocol
- (void)readPreferences
{
  NSString       *val;
  BOOL           bVal;
  int            state;
  NSString       *buildToolDefault;
  PCFileManager  *pcfm = [PCFileManager defaultManager];

  /* some heuristic to find the best make default */
  buildToolDefault = [pcfm findExecutableToolFrom:
                           [NSArray arrayWithObjects:
                                      @"usr/local/bin/gmake",
                                    @"usr/bin/gmake",
                                    @"usr/local/bin/make",
                                    @"usr/bin/make",
                                    @"bin/make",
                                    nil]];


  NSLog(@"Build tool found: %@", buildToolDefault);

  val = [prefs stringForKey:SuccessSound defaultValue:@""];
  [successField setStringValue:val];
  val = [prefs stringForKey:FailureSound defaultValue:@""];
  [failureField setStringValue:val];

  val = [prefs stringForKey:RootBuildDirectory defaultValue:@""];
  [rootBuildDirField setStringValue:val];

  val = [prefs stringForKey:BuildTool defaultValue:buildToolDefault];
  if (val)
    [buildToolField setStringValue:val];

  bVal = [prefs boolForKey:DeleteCacheWhenQuitting defaultValue:YES];
  state = bVal ? NSOnState : NSOffState;
  [deleteCache setState:state];

  bVal = [prefs boolForKey:PromptOnClean defaultValue:YES];
  state = bVal ? NSOnState : NSOffState;
  [promptOnClean setState:state];
}

- (NSView *)view
{
  return buildingView;
}

// Actions
- (void)setSuccessSound:(id)sender
{
  NSArray  *types = [NSArray arrayWithObjects:@"snd",@"au",@"wav",nil];
  NSArray  *files;
  NSString *path;

  if (sender == successField)
    {
      path = [successField stringValue];
    }
  else
    {
      files = [[PCFileManager defaultManager] 
	filesOfTypes:types
	   operation:PCOpenFileOperation
	    multiple:NO
	       title:@"Choose Success Sound"
	     accView:nil];
      path = [files objectAtIndex:0];
    }

/*    {
      NSSound *sound;

      sound = [[NSSound alloc] initWithContentsOfFile:path byReference:YES];
      [sound play];
      RELEASE(sound);
    }*/

  if (path)
    {
      [successField setStringValue:path];
      [prefs setString:path forKey:SuccessSound notify:YES];
    }

  [[buildingView window] makeFirstResponder:successField];
}

- (void)setFailureSound:(id)sender
{
  NSArray  *types = [NSArray arrayWithObjects:@"snd",@"au",@"wav",nil];
  NSArray  *files;
  NSString *path;

  if (sender == failureField)
    {
      path = [failureField stringValue];
    }
  else
    {
      files = [[PCFileManager defaultManager] 
	filesOfTypes:types
	   operation:PCOpenFileOperation
	    multiple:NO
	       title:@"Choose Failure Sound"
	     accView:nil];
      path = [files objectAtIndex:0];
    }

  if (path)
    {
      [failureField setStringValue:path];
      [prefs setString:path forKey:FailureSound notify:YES];
    }

  [[buildingView window] makeFirstResponder:failureField];
}

- (void)setRootBuildDir:(id)sender
{
  NSArray  *files;
  NSString *path;

  if (sender == rootBuildDirField)
    {
      path = [rootBuildDirField stringValue];
    }
  else
    {
      files = [[PCFileManager defaultManager] 
	filesOfTypes:nil
	   operation:PCOpenDirectoryOperation
	    multiple:NO
	       title:@"Choose Build Directory"
	     accView:nil];
      path = [files objectAtIndex:0];
    }

  if (path)
    {
      [rootBuildDirField setStringValue:path];
      [prefs setString:path forKey:RootBuildDirectory notify:YES];
    }

  [[buildingView window] makeFirstResponder:rootBuildDirField];
}

- (void)setBuildTool:(id)sender
{
  NSArray  *files;
  NSString *path;

  if (sender == buildToolField)
    {
      path = [buildToolField stringValue];
    }
  else
    {
      files = [[PCFileManager defaultManager] 
	filesOfTypes:nil
	   operation:PCOpenFileOperation
	    multiple:NO
	       title:@"Choose Build Tool"
	     accView:nil];
      path = [files objectAtIndex:0];
    }

  if (path)
    {
      [buildToolField setStringValue:path];
      [prefs setString:path forKey:BuildTool notify:YES];
    }

  [[buildingView window] makeFirstResponder:buildToolField];
}

- (void)setDeleteCache:(id)sender
{
  BOOL state;

  if (deleteCache == nil)
    {// HACK!!! need to be fixed in GNUstep
      deleteCache = sender;
      return;
    }

  state = ([sender state] == NSOffState) ? NO : YES;
  [prefs setBool:state forKey:DeleteCacheWhenQuitting notify:YES];
}

- (void)setPromptOnClean:(id)sender
{
  BOOL state;

  if (promptOnClean == nil)
    {// HACK!!! need to be fixed in GNUstep
      promptOnClean = sender;
      return;
    }

  state = ([sender state] == NSOffState) ? NO : YES;
  [prefs setBool:state forKey:PromptOnClean notify:YES];
}

@end

