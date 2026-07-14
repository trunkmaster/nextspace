/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2005-2015 Free Software Foundation

   Authors: Serg Stoyan
            Riccardo Mottola

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef _PCPreferencesProtocols_h_
#define _PCPreferencesProtocols_h_

#import <Foundation/NSObject.h>

#define PCSavePeriodDidChangeNotification @"PCSavePeriodDidChangeNotification"
#define PCPreferencesDidChangeNotification @"PCPreferencesDidChangeNotification"

@protocol PCPreferences <NSObject>

- (NSColor *)colorFromString:(NSString *)colorString;
- (NSString *)stringFromColor:(NSColor *)color;

- (NSString *)stringForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key
	      defaultValue:(NSString *)defaultValue;

- (BOOL)boolForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key 
      defaultValue:(BOOL)defaultValue;

- (float)floatForKey:(NSString *)key;
- (float)floatForKey:(NSString *)key
	defaultValue:(float)defaultValue;

- (NSColor *)colorForKey:(NSString *)key;
- (NSColor *)colorForKey:(NSString *)key
        defaultValue:(NSColor *)defaultValue;

- (void)setString:(NSString *)stringValue 
	   forKey:(NSString *)aKey
	   notify:(BOOL)notify;
- (void)setBool:(BOOL)boolValue
	 forKey:(NSString *)aKey
	 notify:(BOOL)notify;
- (void)setFloat:(float)floatValue
	  forKey:(NSString *)aKey
	  notify:(BOOL)notify;
- (void)setColor:(NSColor *)color
	  forKey:(NSString *)aKey
	  notify:(BOOL)notify;
@end

@protocol PCPrefsSection <NSObject>

- (id)initWithPrefController:(id <PCPreferences>)aPrefs;
- (void)readPreferences;
- (NSView *)view;

@end

#endif
