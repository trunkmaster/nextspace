/*
  GormPopUpButtonAttributesInspector.m

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

#include "GormPopUpButtonAttributesInspector.h"

/*
  IBObjectAdditions category
 */
@implementation	NSPopUpButton (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormPopUpButtonAttributesInspector";
}
@end


@implementation GormPopUpButtonAttributesInspector

- (id) init
{
  if ([super init] == nil)
    return nil;


  if ([NSBundle loadNibNamed: @"GormNSPopUpButtonInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormPopUpButtonInspector");
      return nil;
    }

  return self;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id) sender
{
  if (sender == typeMatrix)
    {
      BOOL pullsDown = [[sender selectedCell] tag] == YES ? YES : NO;
      NSArray *itemArray = [[object itemArray] copy];
      NSEnumerator *en = [itemArray objectEnumerator];
      id o = nil;
      
      [object removeAllItems];
      [object setPullsDown: pullsDown];
      while ((o = [en nextObject]) != nil)
	{
	  id<NSMenuItem> mi = nil;
	  
	  [object addItemWithTitle: [o title]];
	  mi = [object lastItem];
	  [mi setAction: NULL]; // @selector(_popUpItemAction:)];
	  [mi setTarget: nil];
	}
    }
  else if (sender == autoenableSwitch)
    {
      [object setAutoenablesItems: ([sender state] == NSOnState)];
    }
  else if (sender == enableSwitch)
    {
      [object setEnabled: ([sender state] == NSOnState)];
    }
  else if (sender == tagForm)
    {
      [object setTag: [[sender cellAtIndex: 0] intValue]];
    }
  else if (sender == defaultItemForm)
    {
      int index = [[sender cellAtIndex: 0] intValue];
      int num = [object numberOfItems];

      // if the user enters more than the number, select the last item.
      index = (index < num && index >= 0) ? index : num;
      [object selectItemAtIndex: index];
    }
  else if (sender == pullDownTitleForm)
    {
      [object setTitle: [[sender cellAtIndex: 0] stringValue]];
    }
  else if (sender == pullDownArrowPopUp)
    {
      [object setPreferredEdge: [[sender selectedItem] tag]];
    }

  [super ok: sender];
}

/* Sync from object ( NSPopUpButton ) changes to the inspector   */
- (void) revert: (id)sender
{
  BOOL pullsDown;
  if ( object == nil)
    return;

  pullsDown = [object pullsDown];
  [typeMatrix selectCellWithTag: pullsDown];
  [autoenableSwitch setState: ([object autoenablesItems] ? NSOnState : NSOffState)];
  [enableSwitch setState: [object isEnabled]];
  [[tagForm cellAtRow: 0 column: 0] setIntValue: [object tag]];
  [[defaultItemForm cellAtRow: 0 column: 0] setIntValue: [object indexOfSelectedItem]];
  [pullDownTitleForm setEnabled: pullsDown];
  [[pullDownTitleForm cellAtIndex: 0]
    setStringValue: pullsDown ? [object title] : @""];
  [pullDownArrowPopUp setEnabled: pullsDown];
  [pullDownArrowPopUp selectItemWithTag: [object preferredEdge]];

  [super revert:sender];
}

/* delegate method for tagForm and defaultItemForm */
-(void) controlTextDidChange:(NSNotification*) aNotification
{
  [self ok:[aNotification object]];
}

@end
