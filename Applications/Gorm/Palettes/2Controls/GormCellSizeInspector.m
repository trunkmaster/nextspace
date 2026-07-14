/* GormCellSizeInspector.m
 *
 * Copyright (C) 2021 Free Software Foundation, Inc.
 *
 * Author:	Gregory Casamento <greg.casamento@gmail.com>
 * Date:	2021
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

#include <InterfaceBuilder/InterfaceBuilder.h>
#include "GormCellSizeInspector.h"

@implementation NSCell (IBObjectAdditions_Matrix)
- (NSString *) sizeInspectorClassName
{
  return @"GormCellSizeInspector";
}
@end

@implementation GormCellSizeInspector

+ (void) initialize
{
  if (self == [GormCellSizeInspector class])
    {
    }
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE(window);
  [super dealloc];
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      if ([NSBundle loadNibNamed: @"GormCellSizeInspector" 
                           owner: self] == NO)
	{
          NSLog(@"Could not open gorm GormViewSizeInspector");
          NSLog(@"self %@", self);
          return nil;
	}

      [[NSNotificationCenter defaultCenter] 
	addObserver: self
	   selector: @selector(controlTextDidEndEditing:)
	       name: NSControlTextDidEndEditingNotification
	     object: nil];

    }
  return self;
}

- (void) ok: (id)sender
{
  id<IBDocuments> document = [(id<IB>)[NSApp delegate] activeDocument];
  
  id parent = [document parentOfObject: object];
  if ([parent respondsToSelector: @selector(cellSize)])
    {
      NSSize size;
      CGFloat w = [width doubleValue];
      CGFloat h = [height doubleValue];
      
      size.width = w;
      size.height = h;
      [parent setCellSize: size];
      [parent sizeToCells];
      [parent setNeedsDisplay: YES];
      
      // Update the document as edited...
      [document touch];
    }
}

- (void) revert: (id)sender
{
  NSLog(@"sender = %@",sender);
}

- (void) controlTextDidEndEditing: (NSNotification*)aNotification
{
  id obj = [aNotification object];
  [super ok: obj];
}

- (void) setObject: (id)anObject
{
  if (anObject != nil && anObject != object)
    {
      id<IBDocuments> document = [(id<IB>)[NSApp delegate] activeDocument];
      id parent = [document parentOfObject: anObject];

      ASSIGN(object, anObject);
      if ([parent respondsToSelector: @selector(cellSize)])
        {
          NSSize size = [parent cellSize];
          [width setDoubleValue: size.width];
          [height setDoubleValue: size.height];
        }
    }
}

@end
