/* Interface of class NSGlyphInfo
   Copyright (C) 2021 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 14-10-2021

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

#ifndef _NSGlyphInfo_h_GNUSTEP_GUI_INCLUDE
#define _NSGlyphInfo_h_GNUSTEP_GUI_INCLUDE

#import <AppKit/AppKitDefines.h>
#import <Foundation/NSObject.h>
#import <AppKit/NSFont.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

typedef unsigned short CGGlyph;

enum {
  NSIdentityMappingCharacterCollection = 0,
  NSAdobeCNS1CharacterCollection,
  NSAdobeGB1CharacterCollection,
  NSAdobeJapan1CharacterCollection,
  NSAdobeJapan2CharacterCollection,
  NSAdobeKorea1CharacterCollection
};
typedef NSUInteger NSCharacterCollection;

@class NSFont, NSString;
  
@interface NSGlyphInfo : NSObject
{
  CGGlyph   _glyphID;
  NSFont   *_font;
  NSString *_baseString;
  NSString *_glyphName;
  NSUInteger _characterIdentifier;
  NSCharacterCollection _characterCollection;
}

/**
 * Creates an NSGlyphInfo object from the specified glyph.
 */
+ (NSGlyphInfo *) glyphInfoWithCGGlyph: (CGGlyph)glyph
                               forFont: (NSFont *)font
                            baseString: (NSString *)string;

/**
 * The string containing the specified glyph
 */
- (NSString *) baseString;

/**
 * The glyph this glyph info object represents.
 */
- (CGGlyph) glyphID;

// Deprecated methods...

/**
 * Creates an NSGlyphInfo object with the given cid.
 */
+ (NSGlyphInfo *)glyphInfoWithCharacterIdentifier:(NSUInteger)cid 
                         collection:(NSCharacterCollection)characterCollection 
                                       baseString:(NSString *)string;

  
/**
 * Creates an NSGlyphInfo object with the given NSGlyph.
 */
+ (NSGlyphInfo *)glyphInfoWithGlyph:(NSGlyph)glyph 
                            forFont:(NSFont *)font 
                         baseString:(NSString *)string;

/**
 * Creates an NSGlyphInfo object with the given glyph name.
 */
+ (NSGlyphInfo *)glyphInfoWithGlyphName:(NSString *)glyphName 
                                forFont:(NSFont *)font 
                             baseString:(NSString *)string;

/**
 * the character identifier, readonly.
 */
- (NSUInteger) characterIdentifier;

/**
 * the character collection, readonly.
 */
- (NSCharacterCollection) characterCollection;

/**
 * the glyph name, readonly.
 */
- (NSString *) glyphName;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSGlyphInfo_h_GNUSTEP_GUI_INCLUDE */

