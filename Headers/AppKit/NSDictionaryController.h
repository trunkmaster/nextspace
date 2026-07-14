/* Definition of class NSDictionaryController
   Copyright (C) 2021 Free Software Foundation, Inc.

   By: Gregory John Casamento
   Date: 16-10-2021

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

#ifndef _NSDictionaryController_h_GNUSTEP_GUI_INCLUDE
#define _NSDictionaryController_h_GNUSTEP_GUI_INCLUDE

#import <AppKit/NSArrayController.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)

APPKIT_EXPORT_CLASS
@interface NSDictionaryControllerKeyValuePair : NSObject
{
  NSString *_key;
  id _value;
  NSString *_localizedKey;
  BOOL _explicitlyIncluded;
}

- (instancetype) init;

/**
 * Returns a copy of the key
 */
- (NSString *) key;
- (void) setKey: (NSString *)key;

/**
 * Returns a strong reference to the value
 */
- (id) value;
- (void) setValue: (id)value;

/**
 * Localized key copy
 */
- (NSString *) localizedKey;
- (void) setLocalizedKey: (NSString *)localizedKey;

/**
 * Is this key value pair included in the underlying dictionary.
 */
- (BOOL) isExplicitlyIncluded;
- (void) setExplicitlyIncluded: (BOOL)flag;

@end

#endif


#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

APPKIT_EXPORT_CLASS
@interface NSDictionaryController : NSArrayController
{
  NSMutableDictionary *_contentDictionary;
  NSString *_initialKey;
  id _initialValue;
  NSArray *_includedKeys;
  NSArray *_excludedKeys;
  NSDictionary *_localizedKeyDictionary;
  NSString *_localizedKeyTable;
  NSUInteger _count;
}

/**
 * Returns a new object conforming to the NSDictionaryControllerKeyValuePair
 * informal protocol.  Overriden from superclass.
 */
- (NSDictionaryControllerKeyValuePair *) newObject;

/**
 * Returns a copy of the initialKey.
 */
- (NSString *) initialKey;
- (void) setInitialKey: (NSString *)initialKey;

/**
 * Returns a strong reference to the initialValue.
 */
- (id) initialValue;
- (void) setInitialValue: (id)value;

/**
 * Returns a copy of the included keys.  Included keys are always represented by a
 * key value pair whether or not they are included in the underlying dictionary.
 */
- (NSArray *) includedKeys;
- (void) setIncludedKeys: (NSArray *)includedKeys;

/**
 * Returns a copy of the included keys.  Included keys are always represented by a
 * key value pair whether or not they are included in the underlying dictionary.
 */
- (NSArray *) excludedKeys;
- (void) setExcludedKeys: (NSArray *)excludedKeys;

/**
 * Returns a copy of the localized key dictionary.
 */
- (NSDictionary *) localizedKeyDictionary;

/**
 * Sets the localized key dictionary.
 */
- (void) setLocalizedKeyDictionary: (NSDictionary *)dict;

/**
 * Returns the keyTable which is the dictionary in strings format.
 */
- (NSString *) localizedKeyTable;

/**
 * Sets the localized keyTable in strings format.
 */
- (void) setLocalizedKeyTable: (NSString *)keyTable;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSDictionaryController_h_GNUSTEP_GUI_INCLUDE */
