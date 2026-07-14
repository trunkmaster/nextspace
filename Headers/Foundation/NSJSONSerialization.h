/**Definition of class NSJSONSerialization
   Copyright (C) 2011-2021 Free Software Foundation, Inc.

   By: David Chisnall <github@theravensnest.org>
   Date: Jul 2011

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import "Foundation/NSObject.h"

@class NSData;
@class NSError;
@class NSInputStream;
@class NSOutputStream;

enum
{
  /**
   * Collection classes created from reading a JSON stream will be mutable.
   */
  NSJSONReadingMutableContainers = (1UL << 0),
  /**
   * Strings in a JSON tree will be mutable.
   */
  NSJSONReadingMutableLeaves     = (1UL << 1),
  /**
   * The parser will read a single value, not just a 
   */
  NSJSONReadingAllowFragments    = (1UL << 2)
};
enum
{
  /**
   * When writing JSON, produce indented output intended for humans to read.
   * If this is not set, then the writer will not generate any superfluous
   * whitespace, producing space-efficient but not very human-friendly JSON.
   */
  NSJSONWritingPrettyPrinted = (1UL << 0)
};
/**
 * A bitmask containing flags from the NSJSONWriting* set, specifying options
 * to use when writing JSON.
 */
typedef NSUInteger NSJSONWritingOptions;
/**
 * A bitmask containing flags from the NSJSONReading* set, specifying options
 * to use when reading JSON.
 */
typedef NSUInteger NSJSONReadingOptions;


/**
 * NSJSONSerialization implements serializing and deserializing acyclic object
 * graphs in JSON.
 */
GS_EXPORT_CLASS
@interface NSJSONSerialization : NSObject
+ (NSData*) dataWithJSONObject: (id)obj
                       options: (NSJSONWritingOptions)opt
                         error: (NSError **)error;
+ (BOOL) isValidJSONObject: (id)obj;
+ (id) JSONObjectWithData: (NSData *)data
                  options: (NSJSONReadingOptions)opt
                    error: (NSError **)error;
+ (id) JSONObjectWithStream: (NSInputStream *)stream
                    options: (NSJSONReadingOptions)opt
                      error: (NSError **)error;
+ (NSInteger) writeJSONObject: (id)obj
                     toStream: (NSOutputStream *)stream
                      options: (NSJSONWritingOptions)opt
                        error: (NSError **)error;
@end
