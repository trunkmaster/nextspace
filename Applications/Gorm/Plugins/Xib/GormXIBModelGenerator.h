/** <title>GormXIBKeyedArchiver</title>

   <abstract>Interface of GormXIBKeyedArchiver</abstract>

   Copyright (C) 2023 Free Software Foundation, Inc.

   Author:  Gregory John Casamento <greg.casamento@gmail.com>
   Date: 2023
   
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

#ifndef GormXIBModelGenerator_H_INCLUDE
#define GormXIBModelGenerator_H_INCLUDE

#import <Foundation/NSObject.h>

@class GormDocument;
@class NSMutableDictionary;
@class NSString;
@class NSData;
@class NSMutableArray;
@class NSMapTable;

@interface GormXIBModelGenerator : NSObject
{
  GormDocument *_gormDocument;
  NSMutableDictionary *_mappingDictionary;
  NSMutableArray *_allIdentifiers;
  NSMapTable *_objectToIdentifier;
}

/**
 * Returns an autoreleased GormXIBModelGenerator object;
 */
+ (instancetype) xibWithGormDocument: (GormDocument *)doc;

/**
 * Initialize with GormDocument object to parse the XML from or into.
 */
- (instancetype) initWithGormDocument: (GormDocument *)doc;

/**
 * The data for the XIB document that has been created
 */
- (NSData *) data;

/**
 * Exports XIB file.  This method starts the process and calls
 * another method that recurses through the objects in the model and 
 * maps any properties as appropriate when exporting.
 */
- (BOOL) exportXIBDocumentWithName: (NSString *)name;

@end

#endif //  GormXIBModelGenerator_H_INCLUDE
