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

#import "PCSavingPrefs.h"

@implementation PCSavingPrefs

// ----------------------------------------------------------------------------
// --- Init and free
// ----------------------------------------------------------------------------

- (id)initWithPrefController:(id <PCPreferences>)aPrefs
{
  self = [super init];

  if ([NSBundle loadNibNamed:@"SavingPrefs" owner:self] == NO)
    {
      NSLog(@"PCSavingPrefs: error loading NIB file!");
    }

  prefs = aPrefs;

  RETAIN(savingView);

  return self;
}

- (void)awakeFromNib
{
  [saveOnQuit setRefusesFirstResponder:YES];
  [keepBackup setRefusesFirstResponder:YES];
}

- (void)dealloc
{
#ifdef DEBUG
  NSLog (@"PCSavingPrefs: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(savingView);

  [super dealloc];
}

// Protocol
- (void)readPreferences
{
  NSString *val;
  BOOL     bVal;
  int      state;

  val = [prefs stringForKey:AutoSavePeriod defaultValue:@"120"];
  [autosaveField setStringValue:val];
  [autosaveSlider setFloatValue:[val floatValue]];

  bVal = [prefs boolForKey:SaveOnQuit defaultValue:YES];
  state = bVal ? NSOnState : NSOffState;
  [saveOnQuit setState:state];

  bVal = [prefs boolForKey:KeepBackup defaultValue:YES];
  state = bVal ? NSOnState : NSOffState;
  [keepBackup setState:state];
}

- (NSView *)view
{
  return savingView;
}

// Actions
- (void)setSaveOnQuit:(id)sender
{
  BOOL state;

  if (saveOnQuit == nil)
    {// HACK!!! need to be fixed in GNUstep
      saveOnQuit = sender;
      return;
    }

  state = ([sender state] == NSOffState) ? NO : YES;
  [prefs setBool:state forKey:SaveOnQuit notify:YES];
}

- (void)setKeepBackup:(id)sender
{
  BOOL state;

  if (keepBackup == nil)
    {// HACK!!! need to be fixed in GNUstep
      keepBackup = sender;
      return;
    }

  state = ([sender state] == NSOffState) ? NO : YES;
  [prefs setBool:state forKey:KeepBackup notify:YES];
}

- (void)setSavePeriod:(id)sender
{
  NSString *periodString;
  
  if (sender == autosaveSlider)
    {
      [autosaveField setIntValue:[sender intValue]];
    }

  periodString = [autosaveField stringValue];
  [prefs setString:periodString forKey:AutoSavePeriod notify:YES];

  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCSavePeriodDidChangeNotification
                  object:periodString];
}

@end

