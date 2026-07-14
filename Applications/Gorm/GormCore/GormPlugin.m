/* GormNibModule.m
 *
 * Copyright (C) 2007 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2007
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
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GormCore/GormPlugin.h>
#include <GormCore/GormDocumentController.h>

@interface NSDocumentController (GormPrivate)
- (NSArray *) types;
- (void) setTypes: (NSArray *)types;
- (BOOL) containsDocumentTypeName: (NSString *)tname;
@end

static Ivar types_ivar(void)
{
  static Ivar iv;
  if (iv == NULL)
    {
      iv = class_getInstanceVariable([NSDocumentController class], "_types");
      NSCAssert(iv, @"Unable to find _types instance variable of NSDocumentController");
    }
  return iv;
}

@implementation NSDocumentController (GormPrivate)
- (NSArray *) types
{
  return object_getIvar(self, types_ivar());
}

- (void) setTypes: (NSArray *)types
{
  object_setIvar(self, types_ivar(), types);
}

- (BOOL) containsDocumentTypeName: (NSString *)tname
{
  NSEnumerator *en = [object_getIvar(self, types_ivar()) objectEnumerator];
  id obj = nil;
  
  while ((obj = [en nextObject]) != nil)
    {
      NSString *name = [obj objectForKey: @"NSName"];
      if([tname isEqualToString: name])
	{
	  return YES;
	}
    }

  return NO;
}
@end


@implementation GormPlugin
- (void) registerDocumentTypeName: (NSString *)name
                humanReadableName: (NSString *)hrName
                    forExtensions: (NSArray *)extensions
{
  NSDocumentController *controller = [GormDocumentController sharedDocumentController];
  NSMutableArray *types = [[controller types] mutableCopy];
  
  if([controller containsDocumentTypeName: name] == NO)
    {
      NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							 name, @"NSName",
						       hrName, @"NSHumanReadableName",
						       extensions, @"NSUnixExtensions",
						       nil];
      [types addObject: dict];
      [controller setTypes: types];
    }
}
@end

