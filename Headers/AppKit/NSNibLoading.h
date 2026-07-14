/*
   NSNibLoading.h

   Copyright (C) 1997, 1999 Free Software Foundation, Inc.

   Author:  Simon Frankau <sgf@frankau.demon.co.uk>
   Date: 1997
   Author:  Richard Frith-Macdonald <richard@branstorm.co.uk>
   Date: 1999

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#ifndef _GNUstep_H_NSNibLoading
#define _GNUstep_H_NSNibLoading
#import <AppKit/AppKitDefines.h>

#import <Foundation/NSObject.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSZone.h>

@class NSString;
@class NSDictionary;
@class NSMutableDictionary;

@interface NSObject (NSNibAwaking)

/**
 * Notification of Loading. This method is called on custom objects
 * once model loading is completed.
 */
- (void) awakeFromNib;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_8, GS_API_LATEST)
/**
 * This method is called on a designable object to notify it that it
 * was created at design time.  This allows IB/Gorm to set up the
 * appearance of the object when loaded into the editor.
 */
- (void) prepareForInterfaceBuilder;
#endif

@end


@interface NSBundle (NSNibLoading)

/**
 * Load the model file specified by fileName using the existing context
 * as the external name table.  The name table contains NSOwner, NSMenu
 * and other well known top level objects with zone as the current
 * memory allocation zone.  This method uses the current mainBundle.
 */
+ (BOOL) loadNibFile: (NSString *)fileName
   externalNameTable: (NSDictionary *)context
	    withZone: (NSZone *)zone;

/**
 * Load the model file specified by aNibName, using owner as the NSOwner.
 * This method calls loadNibFile:externalNameTable:withZone:
 */
+ (BOOL) loadNibNamed: (NSString *)aNibName
		owner: (id)owner;

/**
 * Load the model file specified by fileName, using the context dictionary
 * to specify top level objects.  This method uses whatever bundle instance
 * it is called on.  This method is called by
 * +loadNibFile:externalNameTable:withZone:
 */
- (BOOL) loadNibFile: (NSString *)fileName
   externalNameTable: (NSDictionary *)context
	    withZone: (NSZone *)zone;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_8, GS_API_LATEST)
/**
 * Loads the model file specified by aNibName with owner as NSOwner. The
 * topLevelObjects array is a return parameter which returns a pointing
 * to the topLevelObjects in this model.
 */
- (BOOL) loadNibNamed: (NSString *)aNibName
		owner: (id)owner
      topLevelObjects: (NSArray **)topLevelObjects;
#endif

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)
/**
 * Returns the path of the model specified by fileName.
 */
- (NSString *) pathForNibResource: (NSString *)fileName;
#endif // GS_API_NONE
@end

#endif /* _GNUstep_H_NSNibLoading */
