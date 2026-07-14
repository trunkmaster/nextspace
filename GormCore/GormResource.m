/* GormResource.m
 *
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2005
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

#include "GormResource.h"

// resource proxy object...
@implementation GormResource
+ (GormResource*)resourceForPath: (NSString *)aPath
{  
  return [GormResource resourceForPath: aPath inWrapper: NO];
}

+ (GormResource*)resourceForPath: (NSString *)aPath inWrapper: (BOOL)flag
{  
  return AUTORELEASE([[GormResource alloc] initWithPath: aPath inWrapper: flag]);
}

- (id) initWithPath: (NSString *)aPath
{
  return [self initWithPath: aPath inWrapper: NO];
}

- (id) initWithPath: (NSString *)aPath inWrapper: (BOOL)flag
{
  NSString *aName = [[aPath lastPathComponent] stringByDeletingPathExtension];
  return [self initWithName: aName path: aPath inWrapper: flag];
}

- (id) initWithData: (NSData *)aData withFileName: (NSString *)aFileName inWrapper: (BOOL)flag
{
  if((self = [self init]))
    {
      path = nil;
      ASSIGN(fileName, aFileName);
      ASSIGN(name, [fileName stringByDeletingPathExtension]);
      ASSIGN(fileType, [fileName pathExtension]);
      ASSIGN(data, aData);
      language = nil;
      isLocalized = NO;
      isSystemResource = NO;
      isInWrapper = flag;
      project = nil;
    }
  return self;
}

- (id) initWithName: (NSString *)aName
	       path: (NSString *)aPath
{
  return [self initWithName: aName path: aPath inWrapper: NO];
}

/**
 * Designated initializer.  
 */
- (id) initWithName: (NSString *)aName
	       path: (NSString *)aPath
	  inWrapper: (BOOL)flag
{
  if((self = [super init]))
    {
      ASSIGN(path, aPath);
      ASSIGN(name, aName);
      ASSIGN(fileName, [aPath lastPathComponent]);
      ASSIGN(fileType, [fileName pathExtension]);
      language = nil;
      isLocalized = NO;
      isSystemResource = NO;
      isInWrapper = flag;
      project = nil;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(name);
  RELEASE(path);
  RELEASE(fileName);
  RELEASE(fileType);
  RELEASE(data);
  [super dealloc];
}

- (void) setName: (NSString *)aName
{
  ASSIGN(name, aName);
}

- (NSString *) name
{
  return name;
}

- (void) setPath: (NSString *)aPath
{
  ASSIGN(path, aPath);
}

- (void) setSystemResource: (BOOL)flag
{
  isSystemResource = flag;
}

- (BOOL) isSystemResource
{
  return isSystemResource;
}

- (void) setInWrapper: (BOOL)flag
{
  isInWrapper = flag;
}

- (BOOL) isInWrapper
{
  return isInWrapper;
}

- (void) setData: (NSData *)aData
{
  ASSIGN(data, aData);
}

- (NSData *) data
{
  return data;
}

- (BOOL) isEqual: (id)object
{
  BOOL result = NO;

  if(object == self)
    result = YES;
  else if([object isKindOfClass: [self class]] == NO)
    result = NO;
  else if([[self name] isEqual: [(GormResource *)object name]])
    result = YES;

  return result;
}

// IBProjectFiles methods.
- (NSString *) fileName
{
  return fileName;
}

- (NSString *) fileType
{
  return fileType;
}

- (BOOL) isLocalized
{
  return isLocalized;
}

- (NSString *) language
{
  return language;
}

- (NSString *) path
{
  return path;
}

- (id<IBProjects>) project
{
  return project;
}
@end
