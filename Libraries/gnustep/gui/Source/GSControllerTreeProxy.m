/* Implementation of class GSControllerTreeProxy
   Copyright (C) 2024 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 24-06-2024

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import "AppKit/NSTreeController.h"

#import "GSControllerTreeProxy.h"
#import "GSBindingHelpers.h"

@implementation GSControllerTreeProxy

- (instancetype) initWithContent: (id)content
		  withController: (id)controller
{
  NSMutableDictionary *dict =
    [NSMutableDictionary dictionaryWithObject:
	       [NSMutableArray arrayWithArray: content]
				       forKey: @"children"];

  self = [super initWithRepresentedObject: dict];
  if (self != nil)
    {
      ASSIGN(_controller, controller);
    }

  return self;
}

- (NSUInteger) count
{
  NSArray *children = [[self representedObject] objectForKey: @"children"];
  return [children count];
}

// This is here so that when the path is specified as "children" it responds
- (NSMutableArray *) children
{
  NSDictionary *ro = [self representedObject];
  NSMutableArray *children = [ro objectForKey: @"children"];
  return children;
}

- (id) value
{
  return [_representedObject objectForKey: @"value"];
}

- (void) setValue: (id)value
{
  [_representedObject setObject: value
			 forKey: @"value"];
}

// These return the value in the cases where the parent class method is called...
- (NSArray *) childNodes
{
  return [self children];
}

- (NSMutableArray *) mutableChildNodes
{
  return [self children];
}

@end

