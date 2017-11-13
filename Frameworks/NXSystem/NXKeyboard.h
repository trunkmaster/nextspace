/*
  Class:               NXKeyboard
  Inherits from:       NSObject
  Class descritopn:    Keyboard configuration manipulation (type, rate, layouts)

  Copyright (C) 2017 Sergii Stoian <stoyan255@ukr.net>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <Foundation/Foundation.h>
#import <NXFoundation/NXDefaults.h>

#define XKB_BASE_LST @"/usr/share/X11/xkb/rules/base.lst"

@interface NXKeyboard : NSObject
{
  NSDictionary *layoutDict;
  NSDictionary *modelDict;
  NSDictionary *variantDict;
  NSDictionary *optionDict;

  NSDictionary *serverConfig;
}

+ (void)configureWithDefaults:(NXDefaults *)defs;

- (NSDictionary *)modelList;
- (NSString *)model;
- (void)setModel:(NSString *)name;

// --- Layouts
- (NSDictionary *)availableLayouts;
- (NSString *)nameForLayout:(NSString *)layoutCode;
- (NSString *)nameForVariant:(NSString *)variantCode;
- (NSDictionary *)variantListForLayout:(NSString *)layout;
- (NSDictionary *)variantListForLanguage:(NSString *)language;

- (NSArray *)layouts;
- (NSArray *)variants;
- (void)addLayout:(NSString *)lCode variant:(NSString *)vCode;
- (void)removeLayout:(NSString *)lCode variant:(NSString *)vCode;

// --- Initial Repeat and Repeat Rate
- (NSInteger)initialRepeat;
- (void)setInitialRepeat:(NSInteger)delay;
- (NSInteger)repeatRate;
- (void)setRepeatRate:(NSInteger)rate;
- (void)setInitialRepeat:(NSInteger)delay rate:(NSInteger)rate;

// --- Various options
- (NSArray *)options;
- (BOOL)setOptions:(NSArray *)opts;

@end

// NXGlobalDomain keys. Strings are started with NXKeyboard prefix
extern NSString *InitialRepeat;
extern NSString *RepeatRate;
extern NSString *Layouts;
extern NSString *Variants;
extern NSString *Model;
extern NSString *Options;
extern NSString *SwitchLayoutKey; // 'grp:' - switching to another layout
extern NSString *ComposeKey;      // 'compose:' - position of Compose key
