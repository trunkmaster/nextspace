/*
  GormTabViewAttributesInspector.m

   Copyright (C) 2001-2015 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: Aug 2001. 2003, 2004
   
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

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormTabViewAttributesInspector.h"

#define ORDERED_PREVIOUS 0
#define ORDERED_NEXT     1


@implementation GormTabViewAttributesInspector


- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }
 
  if ([NSBundle loadNibNamed: @"GormTabViewInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormTabViewInspector");
      return nil;
    }

  return self;
}

- (void) ok: (id)sender
{
  if (sender == typeMatrix)
    {
      unsigned int type = 0;

      switch([[sender selectedCell] tag])
        {
	  case 0:
	    type = NSTopTabsBezelBorder;
	    break;
	  case 5:
	    type = NSLeftTabsBezelBorder;
	    break;
	  case 1:
	    type = NSBottomTabsBezelBorder;
	    break;
	  case 6:
	    type = NSRightTabsBezelBorder;
	    break;
	  case 2:
	    type = NSNoTabsBezelBorder;
	    break;
	  case 3:
	    type = NSNoTabsLineBorder;
	    break;
	  case 4:
	    type = NSNoTabsNoBorder;
	    break;
	  default:
	    break;
	}
      [object setTabViewType: type];
    }
  else if (sender == allowtruncate)
    {
      BOOL flag;
      flag = ([allowtruncate state] == NSOnState) ? YES : NO;
      [object setAllowsTruncatedLabels:flag];
    }
  else if (sender == itemStepper )
    {
      int number = [itemStepper intValue];
      [itemLabel setStringValue:[[object tabViewItemAtIndex:number] label]];
      [itemIdentifier setStringValue:[[object tabViewItemAtIndex:number] identifier]];
      [object selectTabViewItemAtIndex:number];
    }
  else if (sender == numberOfItemsField)
    {
      int newNumber = [[numberOfItemsField stringValue] intValue];

      if (newNumber <= 0) 
	{
	  [numberOfItemsField setStringValue:[NSString stringWithFormat:@"%ld",(long int)[object numberOfTabViewItems]]];
	  return; 
	}
      if ( newNumber > [object numberOfTabViewItems] ) 
	{
	  int i;
	  NSTabViewItem *newTabItem;
	  id document = [(id<IB>)[NSApp delegate] documentForObject: object];
	      
	  for (i=([object numberOfTabViewItems]+1);i<=newNumber;i++)
	    {
	      NSString *ident = [NSString stringWithFormat: @"item %i",i];
	      newTabItem = [(NSTabViewItem *)[NSTabViewItem alloc] initWithIdentifier: (id)ident];
	      [newTabItem setLabel: [NSString stringWithFormat: @"Item %i",i]]; 
	      [newTabItem setView:[[NSView alloc] init]];
	      [object addTabViewItem:newTabItem];
	      [document attachObject: newTabItem toParent: object];
	    }
	}
      else 
	{
	  int i;
	  for (i=([object numberOfTabViewItems]-1);i>=newNumber;i--)
	    {
	      id item = [object tabViewItemAtIndex:i];
	      id document = [(id<IB>)[NSApp delegate] documentForObject: item];

	      [object selectFirstTabViewItem: self];
	      [object removeTabViewItem: item];
	      if(document != nil)
		{
		  [document detachObject: item];
		}
	    }
	}
      [itemStepper setMaxValue: (newNumber - 1)];
    }
  else if ( sender == itemLabel )
    {
      if ([[itemLabel stringValue] isEqualToString:@""] == NO)
	{
	  [[object selectedTabViewItem] setLabel:[itemLabel stringValue]];
	}
    }
  else if ( sender == itemIdentifier )
    {
      if ([[itemIdentifier stringValue] isEqualToString:@""] == NO)
	{
	  [[object selectedTabViewItem] setIdentifier:[itemIdentifier stringValue]];
	}
    }
  else if ( sender == itemPrevious ) 
    {
      NSTabViewItem *tbItem = [object selectedTabViewItem];
      int selectedItem = [object indexOfTabViewItem:tbItem];

      /* We Should disabled UI ? with delegate tabView:didSelectTabViewItem: */
      if ( selectedItem <= 0 ) { 
	return;
      }

      [tbItem retain];
      [object removeTabViewItem:tbItem];
      [object insertTabViewItem:tbItem atIndex:(selectedItem - 1)];
      [object selectTabViewItemAtIndex:(selectedItem - 1)];
      [tbItem release];
    }
  else if (sender == itemNext ) 
    {
      NSTabViewItem *tbItem = [object selectedTabViewItem];
      int selectedItem = [object indexOfTabViewItem:tbItem];

      /* We Should disabled UI ? with delegate tabView:didSelectTabViewItem: */
      if ( selectedItem >= ([object numberOfTabViewItems] -1) ) {
	return;
      }

      [tbItem retain];
      [object removeTabViewItem:tbItem];
      [object insertTabViewItem:tbItem atIndex:(selectedItem + 1)];
      [object selectTabViewItemAtIndex:(selectedItem + 1)];
      [tbItem release];
    }

  [object setNeedsDisplay: YES];
  
  [super ok: sender];
}


- (void) revert :(id) sender
{
  unsigned int numberOfTabViewItems;
  
  if ( object == nil ) 
    return;

  numberOfTabViewItems=[object numberOfTabViewItems];
  
  [numberOfItemsField setStringValue:[NSString stringWithFormat:@"%i",numberOfTabViewItems]];

  [itemStepper setMaxValue:(numberOfTabViewItems -1)];

  [itemLabel setStringValue:[[object selectedTabViewItem] label]];
  [itemIdentifier setStringValue:[[object selectedTabViewItem] identifier]];
}


-(void) controlTextDidChange:(NSNotification *)aNotification
{
  [self ok:[aNotification object]];
}


@end
