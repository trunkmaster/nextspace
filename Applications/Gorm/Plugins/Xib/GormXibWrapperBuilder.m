/* GormWrapperBuilder
 *
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import <GormCore/GormCore.h>

#import "GormXIBModelGenerator.h"

@interface GormXibWrapperBuilder : GormWrapperBuilder
@end

@implementation GormXibWrapperBuilder

+ (NSString *) fileType
{
  return @"GSXibFileType";
}

- (NSFileWrapper *) buildFileWrapperWithDocument: (GormDocument *)doc
{
  GormXIBModelGenerator *generator = [GormXIBModelGenerator xibWithGormDocument: doc];
  NSData *data = [generator data];
  NSFileWrapper *fileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: data];

  return fileWrapper;
}

@end
