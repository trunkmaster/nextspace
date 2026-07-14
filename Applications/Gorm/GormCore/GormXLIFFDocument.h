/* GormXLIFFDocument.h
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef GormXLIFFDocument_H_INCLUDE
#define GormXLIFFDocument_H_INCLUDE

#import <Foundation/NSObject.h>

@class NSMutableDictionary;
@class NSString;
@class NSXMLDocument;
@class GormDocument;

@interface GormXLIFFDocument : NSObject
{
  GormDocument *_gormDocument;

  NSString *_objectId;
  NSString *_targetString;
  NSString *_sourceString;
  NSMutableDictionary *_translationDictionary;
  
  BOOL _source;
  BOOL _target;

}

/**
 * Returns an autoreleased GormXLIFFDocument object;
 */
+ (instancetype) xliffWithGormDocument: (GormDocument *)doc;

/**
 * Initialize with GormDocument object to parse the XML from or into.
 */
- (instancetype) initWithGormDocument: (GormDocument *)doc;

/**
 * Exports XLIFF file for CAT.  This method starts the process and calls
 * another method that recurses through the objects in the model and pulls
 * any translatable elements.
 */
- (BOOL) exportXLIFFDocumentWithName: (NSString *)name
                  withSourceLanguage: (NSString *)slang
                   andTargetLanguage: (NSString *)tlang;

/**
 * Import XLIFF Document withthe name filename
 */
- (BOOL) importXLIFFDocumentWithName: (NSString *)filename;

@end

#endif // GormXLIFFDocument_H_INCLUDE
