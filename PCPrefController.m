/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2015 Free Software Foundation

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

#import <ProjectCenter/PCDefines.h>
#import <ProjectCenter/PCLogController.h>
#import <ProjectCenter/PCBundleManager.h>

#import "PCPrefController.h"
#import <Protocols/Preferences.h>

@implementation PCPrefController


// ===========================================================================
// ==== Class methods
// ===========================================================================

static PCPrefController *_prefCtrllr = nil;
  
+ (PCPrefController *)sharedPCPreferences
{
  if (!_prefCtrllr)
    {
      _prefCtrllr = [[PCPrefController alloc] init];
    }
  
  return _prefCtrllr;
}

//
- (id)init
{
  if (!(self = [super init]))
    {
      return nil;
    }
    
  [self loadPrefsSections];

  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog(@"PCPrefController: dealloc");
#endif
  
  RELEASE(panel);
  [super dealloc];
}

- (void)awakeFromNib
{
}

// ----------------------------------------------------------------------------
// --- color utility method
// ----------------------------------------------------------------------------
- (NSColor *)colorFromString:(NSString *)colorString
{
  NSArray  *colorComponents;
  NSString *colorSpaceName;
  NSColor  *color;

  colorComponents = [colorString componentsSeparatedByString:@" "];
  colorSpaceName = [colorComponents objectAtIndex:0];

  if ([colorSpaceName isEqualToString:@"White"]) // Treat as WhiteColorSpace
    {
      color = [NSColor 
	colorWithCalibratedWhite:[[colorComponents objectAtIndex:1] floatValue]
       			   alpha:1.0];
    }
  else // Treat as RGBColorSpace
    {
      color = [NSColor 
	colorWithCalibratedRed:[[colorComponents objectAtIndex:1] floatValue]
			 green:[[colorComponents objectAtIndex:2] floatValue]
			  blue:[[colorComponents objectAtIndex:3] floatValue]
			 alpha:1.0];
    }

  return color;
}

- (NSString *)stringFromColor:(NSColor *)color
{
  NSString *colorString;

  colorString = nil;
  if ([[color colorSpaceName] isEqualToString:NSCalibratedWhiteColorSpace])
    {
      colorString = [NSString stringWithFormat:@"White %0.1f", 
		  [color whiteComponent]];
    }
  else
    {
      if (![[color colorSpaceName] isEqualToString:NSCalibratedRGBColorSpace])
	color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
      colorString = [NSString stringWithFormat:@"RGB %0.1f %0.1f %0.1f",
			      [color redComponent], 
			      [color greenComponent],
			      [color blueComponent]];
    }

  return colorString;
}

// ----------------------------------------------------------------------------
// --- Accessors
// ----------------------------------------------------------------------------

- (NSString *)stringForKey:(NSString *)key
{
  return [self stringForKey:key defaultValue:nil];
}

- (NSString *)stringForKey:(NSString *)key
	      defaultValue:(NSString *)defaultValue
{
  NSString *stringValue = [[NSUserDefaults standardUserDefaults]
			    objectForKey:key];

  if (stringValue)
    {
      return stringValue;
    }
  else if (defaultValue)
    {
      [self setString:defaultValue forKey:key notify:NO];
      return defaultValue;
    }

  return defaultValue; // returns nil
}

- (BOOL)boolForKey:(NSString *)key
{
  return [self boolForKey:key defaultValue:-1];
}

- (BOOL)boolForKey:(NSString *)key
      defaultValue:(BOOL)defaultValue
{
  NSString *stringValue = [[NSUserDefaults standardUserDefaults]
			    objectForKey:key];

  if (stringValue)
    {
      return [stringValue boolValue];
    }
  else if (defaultValue > 0)
    {
      [self setBool:defaultValue forKey:key notify:NO];
      return defaultValue;
    }

  return defaultValue; // returns -1
}

- (float)floatForKey:(NSString *)key
{
  return [self floatForKey:key defaultValue:0.0];
}

- (float)floatForKey:(NSString *)key defaultValue:(float)defaultValue
{
  NSString *stringValue = [[NSUserDefaults standardUserDefaults]
			    objectForKey:key];

  if (stringValue)
    {
      return [stringValue floatValue];
    }
  else
    {
      [self setFloat:defaultValue forKey:key notify:NO];
      return defaultValue;
    }
}

- (NSColor *)colorForKey:(NSString *)key
{
  return [self colorForKey:key defaultValue:nil];
}

- (NSColor *)colorForKey:(NSString *)key
	    defaultValue:(NSColor *)defaultValue
{
  NSString *stringValue = [[NSUserDefaults standardUserDefaults]
			    objectForKey:key];

  if (stringValue)
    {
      NSColor *color;

      color = [self colorFromString:stringValue];
      return color;
    }
  else if (defaultValue)
    {
      [self setColor:defaultValue forKey:key notify:NO];
      return defaultValue;
    }

  return defaultValue; // returns nil
}

- (void)setString:(NSString *)stringValue 
	   forKey:(NSString *)aKey
	   notify:(BOOL)notify
{
  [[NSUserDefaults standardUserDefaults] setObject:stringValue
					    forKey:aKey];

  if (notify)
    {
      [[NSNotificationCenter defaultCenter] 
	postNotificationName:PCPreferencesDidChangeNotification
		      object:self];
    }
}

- (void)setBool:(BOOL)boolValue
	 forKey:(NSString *)aKey
	 notify:(BOOL)notify
{
  NSString *stringValue = boolValue ? @"YES" : @"NO";

  [[NSUserDefaults standardUserDefaults] setObject:stringValue
					    forKey:aKey];

  if (notify)
    {
      [[NSNotificationCenter defaultCenter] 
	postNotificationName:PCPreferencesDidChangeNotification
		      object:self];
    }
}

- (void)setFloat:(float)floatValue
	  forKey:(NSString *)aKey
	  notify:(BOOL)notify
{
  NSString *stringValue = [NSString stringWithFormat:@"%0.1f", floatValue];

  [[NSUserDefaults standardUserDefaults] setObject:stringValue
					    forKey:aKey];

  if (notify)
    {
      [[NSNotificationCenter defaultCenter] 
	postNotificationName:PCPreferencesDidChangeNotification
		      object:self];
    }
}

- (void)setColor:(NSColor *)color 
	   forKey:(NSString *)aKey
	   notify:(BOOL)notify
{
  NSString *stringValue;

  stringValue = [self stringFromColor:color];
  [[NSUserDefaults standardUserDefaults] setObject:stringValue
					    forKey:aKey];

  if (notify)
    {
      [[NSNotificationCenter defaultCenter] 
	postNotificationName:PCPreferencesDidChangeNotification
		      object:self];
    }
}

- (void)loadPrefsSections
{
  PCBundleManager    *bundleManager = [[PCBundleManager alloc] init];
  NSDictionary       *bundlesInfo;
  NSEnumerator       *enumerator;
  NSString           *bundlePath;
  NSString           *sectionName;
  id<PCPrefsSection> section;

  sectionsDict = [[NSMutableDictionary alloc] init];

  bundlesInfo = [bundleManager infoForBundlesType:@"preferences"];
  enumerator = [[bundlesInfo allKeys] objectEnumerator];
  while ((bundlePath = [enumerator nextObject]))
    {
      sectionName = [[bundlesInfo objectForKey:bundlePath] 
				  objectForKey:@"Name"];
      section = [bundleManager 
	objectForBundleWithName:sectionName
			   type:@"preferences"
		       protocol:@protocol(PCPrefsSection)];
      [section initWithPrefController:self];
      [section readPreferences];
      [sectionsDict setObject:section forKey:sectionName];
    }
}

- (void)showPanel:(id)sender
{
  if (panel == nil 
      && [NSBundle loadNibNamed:@"Preferences" owner:self] == NO)
    {
      PCLogError(self, @"error loading NIB file!");
      return;
    }

  [panel setFrameAutosaveName:@"Preferences"];
  if (![panel setFrameUsingName: @"Preferences"])
    {
      [panel center];
    }

  [self loadPrefsSections];

  // The popup and selected view
  [popupButton removeAllItems];
  [popupButton addItemsWithTitles:[[sectionsDict allKeys] 
   	 sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
  [popupButton selectItemAtIndex:0];
  [self popupChanged:popupButton];

  [panel makeKeyAndOrderFront:self];
}

// Actions
- (void)popupChanged:(id)sender
{
  id<PCPrefsSection> section;
  NSView             *view;

  section = [sectionsDict objectForKey:[sender titleOfSelectedItem]];
  view = [section view];

  [sectionsView setContentView:view];
}

- (void)changeFont:(id)sender
{
  NSLog(@"PCPrefController: changeFont");
}

@end
