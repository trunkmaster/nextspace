/* GormGeneralPref.m
 *
 * Copyright (C) 2003, 2004, 2005 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2003, 2004, 2005
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include "GormGeneralPref.h"

static NSString *BACKUPFILE=@"BackupFile";
static NSString *INTTYPE=@"ClassViewType";
static NSString *REPAIRFILE=@"GormRepairFileOnLoad";

@implementation GormGeneralPref

- (id) init
{
  _view = nil;

  self = [super init];
  
  if ( ! [NSBundle loadNibNamed:@"GormPrefGeneral" owner:self] )
    {
      NSLog(@"Can not load bundle GormPrefGeneral");
      return nil;
    }

  _view =  [[window contentView] retain];

  //Defaults
  {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *intType = [defaults stringForKey: INTTYPE];
 
    [backupButton setState: [defaults integerForKey: BACKUPFILE]];
    // [checkConsistency setState: ([defaults boolForKey: REPAIRFILE]?NSOnState:NSOffState)];
    
    // set the interface matrix...
    if([intType isEqual: @"Outline"])
      {
	[interfaceMatrix setState: NSOnState atRow: 0 column: 0];
	[interfaceMatrix setState: NSOffState atRow: 1 column: 0];
      }
    else if([intType isEqual: @"Browser"])
      {
	[interfaceMatrix setState: NSOffState atRow: 0 column: 0];
	[interfaceMatrix setState: NSOnState atRow: 1 column: 0];
      }
  }

  return self;
}

- (void) dealloc
{
  TEST_RELEASE(_view);
  [super dealloc];
}

- (NSView *) view 
{
  return _view;
}

- (void) backupAction: (id)sender
{
  NSUserDefaults *defaults =  [NSUserDefaults standardUserDefaults];
  [defaults setInteger:[backupButton state] forKey:BACKUPFILE];
}

- (void) classesAction: (id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  // NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  
  if([[interfaceMatrix cellAtRow: 0 column: 0] state] == NSOnState)
    {
      [defaults setObject: @"Outline" forKey: INTTYPE];
    }
  else if([[interfaceMatrix cellAtRow: 1 column: 0] state] == NSOnState)
    {
      [defaults setObject: @"Browser" forKey: INTTYPE];
    }
  
  // let the world know it's changed.
  // [nc postNotificationName: GormSwitchViewPreferencesNotification
  //     object: nil];
  
}

- (void) consistencyAction: (id)sender
{
  NSUserDefaults *defaults =  [NSUserDefaults standardUserDefaults];
  [defaults setBool: (([checkConsistency state] == NSOnState)?YES:NO) 
	    forKey: REPAIRFILE];
}
@end

