/* Implementation of class NSGlyphInfo
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

/*
 * This class should use data from this project for it's character collection data...
 * https://github.com/adobe-type-tools/cmap-resources
 * NOTE: This class is a place holder until the above is better understood.
 */

#import <Foundation/NSString.h>

#import "AppKit/NSGlyphInfo.h"
#import "AppKit/NSFont.h"
#import "AppKit/NSGlyphGenerator.h"

@implementation NSGlyphInfo

/*
 * The purpose of this method is to determine the mapping as it is not
 * always going to be one to one.
 */
- (void) _characterMapping
{
  _characterCollection = NSIdentityMappingCharacterCollection;
  _characterIdentifier = _glyphID;
}

// GNUstep specific method...
- (instancetype) initWithCGGlyph: (CGGlyph)g
                         forFont: (NSFont *)f
                      baseString: (NSString *)s
{
  self = [super init];
  if (self != nil)
    {
      _glyphID = g;
      ASSIGN(_font, f);
      ASSIGN(_baseString, s);
      [self _characterMapping];
    }
  return self;
}

+ (NSGlyphInfo *) glyphInfoWithCGGlyph: (CGGlyph)glyph
                               forFont: (NSFont *)font
                            baseString: (NSString *)string
{
  return [[NSGlyphInfo alloc] initWithCGGlyph: glyph
                                      forFont: font
                                   baseString: string];
}

- (NSString *) baseString
{
  return _baseString;
}

- (CGGlyph) glyphID
{
  return _glyphID;
}

// Deprecated methods...

+ (NSGlyphInfo *)glyphInfoWithCharacterIdentifier:(NSUInteger)cid 
                         collection:(NSCharacterCollection)characterCollection 
                                       baseString:(NSString *)string
{
  NSGlyphInfo *gi = [NSGlyphInfo glyphInfoWithCGGlyph: (CGGlyph)cid
                                              forFont: nil
                                           baseString: string];

  gi->_characterCollection = characterCollection;
  return gi;
}

  
+ (NSGlyphInfo *)glyphInfoWithGlyph:(NSGlyph)glyph 
                            forFont:(NSFont *)font 
                         baseString:(NSString *)string
{
  return nil;
}

+ (NSGlyphInfo *)glyphInfoWithGlyphName:(NSString *)glyphName 
                                forFont:(NSFont *)font 
                             baseString:(NSString *)string
{
  return nil;
}

- (NSUInteger) characterIdentifier
{
  return _characterIdentifier;
}


- (NSCharacterCollection) characterCollection
{
  return _characterCollection;
}

- (NSString *) glyphName
{
  return _glyphName;
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"GID %4x", _glyphID];
}

@end
