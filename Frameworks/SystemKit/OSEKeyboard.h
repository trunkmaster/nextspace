/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

/*
  Class:               OSEKeyboard
  Inherits from:       NSObject
  Class descritopn:    Keyboard configuration manipulation (type, rate, layouts)
*/

#import <Foundation/Foundation.h>
#import <DesktopKit/NXTDefaults.h>

#define XKB_BASE_LST @"/usr/share/X11/xkb/rules/base.lst"

@interface OSEKeyboard : NSObject
{
  NSDictionary *layoutDict;
  NSDictionary *modelDict;
  NSDictionary *variantDict;
  NSDictionary *optionDict;
}

+ (void)configureWithDefaults:(NXTDefaults *)defs;

- (NSDictionary *)modelList;
- (NSString *)model;
- (BOOL)setModel:(NSString *)name;

- (void)setNumLockState:(NSInteger)state;

// --- Layouts and options
- (NSDictionary *)availableLayouts;
- (NSString *)nameForLayout:(NSString *)layoutCode;
- (NSString *)nameForVariant:(NSString *)variantCode;
- (NSDictionary *)variantListForLayout:(NSString *)layout;
- (NSDictionary *)variantListForLanguage:(NSString *)language;

- (NSArray *)layouts;
- (NSArray *)variants;
- (NSArray *)options;
- (void)addLayout:(NSString *)lCode variant:(NSString *)vCode;
- (void)removeLayout:(NSString *)lCode variant:(NSString *)vCode;
- (BOOL)setLayouts:(NSArray *)layouts
          variants:(NSArray *)variants
           options:(NSArray *)options;

// --- Initial Repeat and Repeat Rate
- (NSInteger)initialRepeat;
- (void)setInitialRepeat:(NSInteger)delay;
- (NSInteger)repeatRate;
- (void)setRepeatRate:(NSInteger)rate;
- (void)setInitialRepeat:(NSInteger)delay rate:(NSInteger)rate;

@end

// NXGlobalDomain keys. Strings are started with OSEKeyboard prefix
extern NSString *OSEKeyboardInitialRepeat;
extern NSString *OSEKeyboardRepeatRate;
extern NSString *OSEKeyboardLayouts;
extern NSString *OSEKeyboardVariants;
extern NSString *OSEKeyboardModel;
extern NSString *OSEKeyboardOptions;
extern NSString *OSEKeyboardNumLockState;
