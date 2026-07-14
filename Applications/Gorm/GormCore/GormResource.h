/** <title>GormResource</title>

   <abstract>This class is a placeholder for a real resource.</abstract>
   
   Copyright (C) 2005 Free Software Foundation, Inc.

   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: Mar 2005
   
   This file is part of the GNUstep GUI Library.

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

#ifndef INCLUDED_GormResource_h
#define INCLUDED_GormResource_h

#include <Foundation/Foundation.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

@class NSString, NSData;

@interface GormResource : NSObject <IBProjectFiles>
{
  NSString        *name;
  NSString        *fileName;
  NSString        *fileType;
  BOOL            isLocalized;
  NSString        *language;
  NSString        *path;
  id<IBProjects>  project;
  BOOL            isSystemResource;
  BOOL            isInWrapper;
  NSData          *data;
}

// factory methods
+ (GormResource *) resourceForPath: (NSString *)path;
+ (GormResource *) resourceForPath: (NSString *)path inWrapper: (BOOL)flag;

// initialization methods
- (id) initWithPath: (NSString *)aPath;
- (id) initWithPath: (NSString *)aPath
          inWrapper: (BOOL)flag;
- (id) initWithName: (NSString *)aName
               path: (NSString *)aPath;
- (id) initWithName: (NSString *)aName
               path: (NSString *)aPath
          inWrapper: (BOOL)flag;
- (id) initWithData: (NSData *)aData 
       withFileName: (NSString *)aFileName 
          inWrapper: (BOOL)flag;

// instances methods
- (void) setName: (NSString *)aName;
- (NSString *) name;
- (void) setSystemResource: (BOOL)flag;
- (BOOL) isSystemResource;
- (void) setInWrapper: (BOOL)flag;
- (BOOL) isInWrapper;
- (void) setData: (NSData *)data;
- (NSData *) data;
- (BOOL) isEqual: (id)object;
@end

#endif
