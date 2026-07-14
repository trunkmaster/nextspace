/*
  GormStepperAttributesInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author: Adam Fedor <fedor@gnu.org>
           Laurent Julliard <laurent@julliard-online.org>
   Date: Aug 2001

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

#include "GormStepperAttributesInspector.h"

// Some simple inspectors.
@interface GormStepperCellAttributesInspector : GormStepperAttributesInspector
@end

@implementation GormStepperCellAttributesInspector
@end

@implementation GormStepperAttributesInspector

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }
  if ([NSBundle loadNibNamed: @"GormNSStepperInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormStepperAttributesInspector");
      return nil;
    }

  return self;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id) sender
{
  if (sender == valueField)
    {
      [object setDoubleValue:[sender doubleValue]];
    }
  else if (sender == minimumValueField)
    {
      [object setMinValue:[sender doubleValue]];
    }
  else if (sender == maximumValueField)
    {
      [object setMaxValue:[sender doubleValue]];
    }
  else if (sender == incrementValueField)
    {
      [object setIncrement:[sender doubleValue]];
    }
  else if (sender == autorepeatButton)
    {
      switch ([(NSButton *)sender state])
	{
	case 0:
	  [object setAutorepeat: NO];
	  break;
	case 1:
	  [object setAutorepeat: YES];
	  break;
	}
    }
  else if (sender == valueWrapsButton)
    {
      switch ([(NSButton *)sender state])
	{
	case 0:
	  [object setValueWraps: NO];
	  break;
	case 1:
	  [object setValueWraps: YES];
	  break;
	}
    }

  [super ok:(id) sender];
}

/* Sync from object ( NSStepper ) changes to the inspector   */
- (void) revert:(id) sender
{
  if (object == nil)
    return;
    
  [valueField setDoubleValue: [object doubleValue]];
  [minimumValueField setDoubleValue: [object minValue]];
  [maximumValueField setDoubleValue: [object maxValue]];
  [incrementValueField setDoubleValue: [object increment]];

  if ([object autorepeat])
    [autorepeatButton setState: 1];
  else
    [autorepeatButton setState: 0];

  if ([object valueWraps])
    [valueWrapsButton setState: 1];
  else
    [valueWrapsButton setState: 0];

  [super revert:sender];
}

/* delegate methods for NSForms */
-(void) controlTextDidChange:(NSNotification *)aNotification
{
  [self ok:[aNotification object]];
}



@end 
