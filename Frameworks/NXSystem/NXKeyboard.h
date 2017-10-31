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
}

+ (void)configureWithDefaults:(NXDefaults *)defs;

- (NSDictionary *)modelList;
- (NSString *)model;
- (void)setModel:(NSString *)name;

- (NSDictionary *)layoutList;
+ (NSDictionary *)currentServerConfig;
- (void)addLayout:(NSString *)name;
- (void)removeLayout:(NSString *)name;
- (void)setLayoutList:(NSArray *)layouts variants:(NSArray *)variants;
- (NSString *)nameForLayout:(NSString *)layoutCode;
// Return list of dictionaries with keys: Layout, Desc.
- (NSDictionary *)variantListForKey:(NSString *)field value:(NSString *)value;
- (NSDictionary *)variantListForLayout:(NSString *)layout;
- (NSDictionary *)variantListForLanguage:(NSString *)language;

- (NSInteger)initialRepeat;
- (void)setInitialRepeat:(NSInteger)delay;
- (NSInteger)repeatRate;
- (void)setRepeatRate:(NSInteger)rate;
- (void)setInitialRepeat:(NSInteger)delay rate:(NSInteger)rate;

@end

// NXGlobalDomain keys. Strings are started with NXKeyboard prefix
extern NSString *InitialRepeat;
extern NSString *RepeatRate;
extern NSString *Layouts;
extern NSString *Model;
extern NSString *Options;
extern NSString *SwitchLayoutKey; // 'grp:' - switching to another layout
extern NSString *ComposeKey;      // 'compose:' - position of Compose key
