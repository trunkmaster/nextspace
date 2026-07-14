/*
  GormTextFieldAttributesInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@gnu.org>
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

#include <GormCore/GormCore.h>

#include "GormTextFieldAttributesInspector.h"


/*
  IBObjectAdditions category
*/

@implementation	NSTextField (IBObjectAdditions)

- (NSString*) inspectorClassName
{
  return @"GormTextFieldAttributesInspector";
}

@end


@implementation GormTextFieldAttributesInspector

- (id) init
{
  if ([super init] == nil)
    return nil;


  if ([NSBundle loadNibNamed: @"GormNSTextFieldInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormTextFieldInspector");
      return nil;
    }

  return self;
}


/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id) sender
{
  if (sender == alignMatrix)
    {
      [object setAlignment: (NSTextAlignment)[[sender selectedCell] tag]];
    }
  else if (sender == backgroundColor)
    {
      [object setBackgroundColor: [sender color]];
    }
  else if (sender == drawsBackground)
    {
      [object setDrawsBackground: [drawsBackground state]];
    }
  else if (sender == textColor)
    {
      [object setTextColor: [sender color]];
    }
  else if ( sender == editableSwitch ) 
    {
      [object setEditable: [editableSwitch state]];
    }
  else if  ( sender == selectableSwitch )
    {
      [object setSelectable: [selectableSwitch state]];
    }
  else if ( sender == scrollableSwitch ) 
    {
      [[object cell] setScrollable: [scrollableSwitch state]];
    }
  else if (sender == borderMatrix)
    {
      BOOL bordered=NO, bezeled=NO;

      if ([[sender cellAtRow: 0 column: 0] state] == NSOnState)
	{
	  bordered = bezeled = NO;
	}
      else if ([[sender cellAtRow: 0 column: 1] state] == NSOnState)
        {
          bordered = YES;
          bezeled = NO;
        } 
      else if ([[sender cellAtRow: 0 column: 2] state] == NSOnState)
	{
	  bordered = NO; bezeled = YES;
	}
      [object setBordered: bordered];
      [object setBezeled: bezeled];
    }
  else if (sender == tagForm)
    {
      [object setTag: [[sender cellAtIndex: 0] intValue]];
    }
  else if (sender == sendActionMatrix)
    {
      BOOL sendActionOnEndEditing = ([[sender cellAtRow: 1 column: 0] state] == NSOnState);
      [[object cell] setSendsActionOnEndEditing: sendActionOnEndEditing];
    }
  else if (sender == singleLineMode)
    {
      [[object cell] setUsesSingleLineMode: [singleLineMode state]];
    }

  [super ok:sender];
}

/* Sync from object ( NSTextField ) changes to the inspector   */
- (void) revert:(id) sender
{
  if (object == nil)
    return;

  [alignMatrix selectCellWithTag: [object alignment]];
  [backgroundColor setColorWithoutAction: [object backgroundColor]];
  [textColor setColorWithoutAction: [object textColor]];
  [drawsBackground setState: 
		     ([object drawsBackground]) ? NSOnState : NSOffState];
  
  [editableSwitch setState:[object isEditable]];
  [selectableSwitch setState:[object isSelectable]];
  [scrollableSwitch setState:[[object cell] isScrollable]];
  [singleLineMode setState:[[object cell] usesSingleLineMode]];
  
  if ([object isBordered] == YES)
    {
      [borderMatrix selectCellAtRow: 0 column: 1];
    }
  else
    {
      if ([object isBezeled] == YES)
        [borderMatrix selectCellAtRow: 0 column: 2];
      else
        [borderMatrix selectCellAtRow: 0 column: 0];
    }

  [[tagForm cellAtIndex: 0] setIntValue: [object tag]];

  if([[object cell] sendsActionOnEndEditing])
    {
      [sendActionMatrix selectCellAtRow: 1 column: 0];
    }
  else
    {
      [sendActionMatrix selectCellAtRow: 0 column: 0];
    }

  [super revert:sender];
}


/* delegate method for tagForm */
-(void) controlTextDidChange:(NSNotification *)aNotification
{
  [self ok: [aNotification object]];
}


@end
