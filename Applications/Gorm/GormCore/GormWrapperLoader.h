/* GormWrapperLoader
 *
 * This class is a subclass of the NSDocumentController
 *
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2006
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

#ifndef INCLUDED_GormWrapperLoader_h
#define INCLUDED_GormWrapperLoader_h

#include <Foundation/Foundation.h>

@class NSFileWrapper, GormDocument, NSString;

@protocol GormWrapperLoader
- (BOOL) loadFileWrapper: (NSFileWrapper *)wrapper withDocument: (GormDocument *)document;
@end

@interface GormWrapperLoader : NSObject <GormWrapperLoader>
{
  GormDocument *document;
}
+ (NSString *) fileType;
- (void) saveSCMDirectory: (NSDictionary *) fileWrappers;
@end

@interface GormWrapperLoaderFactory : NSObject
+ (GormWrapperLoaderFactory *) sharedWrapperLoaderFactory;
+ (void) registerWrapperLoaderClass: (Class) aClass;
- (id<GormWrapperLoader>) wrapperLoaderForType: (NSString *) type;
@end

#endif
