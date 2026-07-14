/** <title>GormScrollViewAttributesInspector</title>

   <abstract>allow user to edit attributes of a scroll view</abstract>

   Copyright (C) 2003 Free Software Foundation, Inc.
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: June 2003

   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

/* All rights reserved */

#include <AppKit/AppKit.h>

#include "GormScrollViewAttributesInspector.h"

@implementation GormScrollViewAttributesInspector
- init
{
  self = [super init];
  if (self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      
      if ([bundle loadNibNamed: @"GormScrollViewAttributesInspector" 
			 owner: self
	       topLevelObjects: NULL] == NO)
	{
	  NSLog(@"Could not open gorm GormScrollViewAttributesInspector");
	  NSLog(@"self %@", self);
	  return nil;
	}
    }

  return self;
}

- (void) _getValuesFromObject
{
  [color setColor: [object backgroundColor]];
  [horizontalScroll setState: [object hasHorizontalScroller]?NSOnState:NSOffState];
  [verticalScroll setState: [object hasVerticalScroller]?NSOnState:NSOffState];
  [horizontalRuler setState: [object hasHorizontalRuler]?NSOnState:NSOffState];
  [verticalRuler setState: [object hasVerticalRuler]?NSOnState:NSOffState];
}

- (void) setObject: (id)anObject
{
  [super setObject: anObject];
  [self _getValuesFromObject];
}

- (void) colorSelected: (id)sender
{
  /* insert your code here */
  [super ok: sender];
  [object setBackgroundColor: [color color]];
}


- (void) verticalSelected: (id)sender
{
  /* insert your code here */
  [super ok: sender];
  [object setHasVerticalScroller: ([verticalScroll state] == NSOnState)];
}


- (void) horizontalSelected: (id)sender
{
  /* insert your code here */
  [super ok: sender];
  [object setHasHorizontalScroller: ([horizontalScroll state] == NSOnState)];
}


- (void) verticalRuler: (id)sender
{
  /* insert your code here */
  [super ok: sender];
  [object setHasVerticalRuler: ([verticalRuler state] == NSOnState)];
}


- (void) horizontalRuler: (id)sender
{
  /* insert your code here */
  [super ok: sender];
  [object setHasHorizontalRuler: ([horizontalRuler state] == NSOnState)];
}


- (void) borderSelected: (id)sender
{
  /* insert your code here */
  [super ok: sender];
  [object setBorderType: [[borderMatrix selectedCell] tag]];
}

@end
