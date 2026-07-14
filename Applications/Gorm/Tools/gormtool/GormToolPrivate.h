/* GormToolPrivate.h
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg.casamento@gmail.com>
 * Date:	2023
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111
 * USA.
 */


#ifndef INCLUDE_GormToolPrivate_H
#define INCLUDE_GormToolPrivate_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import <GormCore/GormPlugin.h>
#import <GormCore/GormDocumentController.h>
#import <GormCore/GormDocument.h>
#import <GormCore/GormClassManager.h>

#import <GNUstepGUI/GSNibLoading.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wobjc-protocol-method-implementation"

// Special method category smashes so that we can register types...

@interface NSDocumentController (ToolPrivate)

- (Class) documentClassForType: (NSString *)type;
- (NSString *) typeFromFileExtension: (NSString *)fileExtension;

@end

@interface GormDocument (ToolPrivate)

+ (BOOL) isNativeType: (NSString *)type;

@end

@interface GormPlugin (ToolPrivate)

- (void) registerDocumentTypeName: (NSString *)name
                humanReadableName: (NSString *)hrName
                    forExtensions: (NSArray *)extensions;

@end

#pragma GCC diagnostic pop

#endif
