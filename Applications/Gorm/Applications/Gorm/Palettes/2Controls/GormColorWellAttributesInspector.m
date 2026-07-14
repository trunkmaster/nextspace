/*
  GormColorWellAttributesInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author: Adam Fedor <fedor@gnu.org>
           Laurent Julliard <laurent@julliard-online.org>
   Date: Aug 2001
   Author: Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2003,2004,2005
   
   This file is part of GNUstep.
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/

/*
  July 2005 : Split inspector classes into separate files.
  Always use ok: revert: methods
  Clean up
  Author : Fabien Vallon <fabien@sonappart.net>
*/

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include "GormColorWellAttributesInspector.h"


/*
  IBObjectAdditions category
*/
@implementation NSColorWell (IBObjectAdditions)
- (NSString *) inspectorClassName
{
  return @"GormColorWellAttributesInspector";
}
@end



@implementation GormColorWellAttributesInspector

-(id) init
{
  if (   ( self = [super init] ) == nil )
    {
      return nil;
    }
  if ([NSBundle loadNibNamed: @"GormNSColorWellInspector" 
		owner: self] == NO)
    {
      NSLog(@"Could not open gorm GormNSColorWellInspector");
      return nil;
    }
    
  return self;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id) sender
{
  if ( sender == initialColorWell ) 
    {
      [object setColor: [initialColorWell color]];
    }
  else if ( sender == disabledSwitch ) 
    {
      [object setEnabled: ([disabledSwitch state] == NSOnState)?NO:YES]; // it's being enabled to show it's disabled!
    }
  else if ( sender == borderedSwitch ) 
    {
      [object setBordered: [borderedSwitch state]];
    }
  else if ( sender == tagField ) 
    {
      [object setTag: [tagField intValue]];
    }

  [super ok:sender];

}


/* Sync from object ( NSColorWell ) changes to the inspector  */
- (void) revert:(id) sender
{
  if ( object == nil )
    return;

  [disabledSwitch setState: ([object isEnabled])?NSOffState:NSOnState];  // On = NO and Off = YES, since we're tracking the Disabled state.
  [borderedSwitch setState: [object isBordered]];
  [initialColorWell setColorWithoutAction: [object color]];
  [tagField setIntValue: [object tag]];

  [super revert:sender];
}


/* delegate method for tag Field */
- (void)controlTextDidChange:(NSNotification *)aNotification
{
  [self ok: [aNotification object]];
}



@end
