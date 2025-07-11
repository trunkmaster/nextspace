/* -*- mode: objc -*- */
//
// Project: Preferences
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

#import <math.h>

#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSData.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSDistributedNotificationCenter.h>

#import <AppKit/NSImage.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSTextView.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSFontPanel.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSOpenPanel.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSAttributedString.h>

#import <DesktopKit/NXTWorkspace.h>

#import "Font.h"

@interface Font (Defaults)

- (BOOL)_getBoolDefault:(NSString *)name;
- (void)_setBoolDefault:(BOOL)aBool forName:(NSString *)name;
- (NSString *)_getStringDefault:(NSString *)name;
- (void)_setStringDefault:(NSString *)string forName:(NSString *)name;
- (float)_getFloatDefault:(NSString *)name;
- (void)_setFloatDefault:(CGFloat)aFloat forName:(NSString *)name;
- (int)_getIntDefault:(NSString *)name;
- (void)_setIntDefault:(int)anInt forName:(NSString *)name;

- (void)_setWMPreference:(NSString *)value forKey:(NSString *)key;
- (void)_setWMFont:(NSFont *)font forKey:(NSString *)key;

@end

@implementation Font (Defaults)

static NSBundle *bundle = nil;
static NSUserDefaults *defaults = nil;
static NSMutableDictionary *domain = nil;
static NSPanel *fontPanel = nil;

// + userFontOfSize:            [Application Font]  <NSUserFont>
// + userFixedPitchFontOfSize: 	[Fixed Pitch Font]	<NSUserFixedPitchFont>
// + systemFontOfSize:          [System Font]       <NSFont>
// + boldSystemFontOfSize:      [Bold System Font]  <NSBoldFont>
// ========================== MACOSX, GS_API_LATEST ===========================
// + toolTipsFontOfSize:        [System Font:11]    <NSToolTipsFont>
// + menuFontOfSize:            [System Font]       <NSMenuFont>
// + messageFontOfSize:         [System Font:14]    <NSMessageFont>
// + controlContentFontOfSize:  [System Font]       <NSControlContentFont>
// + labelFontOfSize:           [System Font]       <NSLabelFont>
// + titleBarFontOfSize:        [Bold System Font]  <NSTitleBarFont>
// + menuBarFontOfSize:         [Bold System Font]  <NSMenuBarFont>
// + paletteFontOfSize:         [Bold System Font]  <NSPaletteFont>
// ========================== MACOSX, GS_API_LATEST ===========================

- (BOOL)_getBoolDefault:(NSString *)name
{
  NSString *str = [domain objectForKey:name];

  if (!str) {
    str = [defaultValues objectForKey:name];
  }
  return [str hasPrefix:@"Y"];
}
- (void)_setBoolDefault:(BOOL)aBool forName:(NSString *)name
{
  [domain setObject:(aBool ? @"YES" : @"NO") forKey:name];
  [defaults setPersistentDomain:domain forName:NSGlobalDomain];
  [defaults synchronize];
}

- (NSString *)_getStringDefault:(NSString *)name
{
  NSString *str = [domain objectForKey:name];

  if (!str) {
    str = [defaultValues objectForKey:name];
  }

  return str;
}
- (void)_setStringDefault:(NSString *)string forName:(NSString *)name
{
  [domain setObject:string forKey:name];
  [defaults setPersistentDomain:domain forName:NSGlobalDomain];
}

- (float)_getFloatDefault:(NSString *)name
{
  NSString *sNum = [domain objectForKey:name];

  if (!sNum) {
    sNum = [defaultValues objectForKey:name];
  }
  return [sNum floatValue];
}
- (void)_setFloatDefault:(CGFloat)aFloat forName:(NSString *)name
{
  [domain setObject:[NSString stringWithFormat:@"%g", aFloat] forKey:name];
  [defaults setPersistentDomain:domain forName:NSGlobalDomain];
}

- (int)_getIntDefault:(NSString *)name
{
  NSString *sNum = [domain objectForKey:name];

  if (!sNum) {
    sNum = [defaultValues objectForKey:name];
  }

  return [sNum intValue];
}
- (void)_setIntDefault:(int)anInt forName:(NSString *)name
{
  [domain setObject:[NSString stringWithFormat:@"%d", anInt] forKey:name];
  [defaults setPersistentDomain:domain forName:NSGlobalDomain];
}

- (void)_setWMPreference:(NSString *)value forKey:(NSString *)key
{
  NSString *wmDefaultsPath;
  NSMutableDictionary *wmDefaults;

  wmDefaultsPath =
      [NSString stringWithFormat:@"%@/.NextSpace/WM.plist", GSDefaultsRootForUser(NSUserName())];

  if (![[NSFileManager defaultManager] fileExistsAtPath:wmDefaultsPath]) {
    NSLog(@"[Font] can't find existing WM defaults database! Creating new...");
    wmDefaults = [NSMutableDictionary new];
  } else {
    wmDefaults = [[NSMutableDictionary alloc] initWithContentsOfFile:wmDefaultsPath];
  }

  [wmDefaults setObject:value forKey:key];
  [wmDefaults writeToFile:wmDefaultsPath atomically:YES];
  [wmDefaults release];
}

- (void)_setWMFont:(NSFont *)font forKey:(NSString *)key
{
  NSMutableString *value;

  // Convert font name into the FontConfig format.
  value = [NSMutableString
      stringWithFormat:@"%@:postscriptname=%@:pixelsize=%.0f:antialias=%@:embeddedbitmap=%@",
                       [font familyName], [font fontName], [font pointSize],
                       [enableAntiAliasingButton state] ? @"true" : @"false",
                       [enableAntiAliasingButton state] ? @"false" : @"true"];
  [self _setWMPreference:value forKey:key];
}

@end

@implementation Font

- (void)dealloc
{
  NSLog(@"FontPrefs -dealloc");

  [domain release];
  [image release];
  [defaultValues dealloc];
  [fontCategories dealloc];

  // if (view) {
  //   [normalExampleString release];
  //   [boldExampleString release];
  // }

  [super dealloc];
}

- (id)init
{
  NSString *imagePath;

  self = [super init];

  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  imagePath = [bundle pathForResource:@"FontPreferences" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  defaultValues = @{
    @"NSFont" : @"Helvetica-Medium",
    @"NSLabelFont" : @"Helvetica-Medium",
    @"NSMenuFont" : @"Helvetica-Medium",
    @"NSMessageFont" : @"Helvetica-Medium",
    @"NSPaletteFont" : @"Helvetica-Bold",
    @"NSTitleBarFont" : @"Helvetica-Bold",
    @"NSBoldFont" : @"Helvetica-Bold",
    @"NSToolTipsFont" : @"Helvetica-Medium",
    @"NSControlContentFont" : @"Helvetica-Medium",
    @"NSUserFont" : @"Helvetica-Medium",
    @"NSUserFixedPitchFont" : @"Keith-Medium",

    @"NSFontSize" : [NSString stringWithFormat:@"%g", 12.0],
    @"NSLabelFontSize" : [NSString stringWithFormat:@"%g", 12.0],
    @"NSMenuFontSize" : [NSString stringWithFormat:@"%g", 12.0],
    @"NSMessageFontSize" : [NSString stringWithFormat:@"%g", 12.0],
    @"NSPaletteFontSize" : [NSString stringWithFormat:@"%g", 12.0],
    @"NSTitleBarFontSize" : [NSString stringWithFormat:@"%g", 12.0],
    @"NSBoldFontSize" : [NSString stringWithFormat:@"%g", 12.0],
    @"NSToolTipsFontSize" : [NSString stringWithFormat:@"%g", 11.0],
    @"NSControlContentFontSize" : [NSString stringWithFormat:@"%g", 12.0],
    @"NSUserFontSize" : [NSString stringWithFormat:@"%g", 12.0],
    @"NSUserFixedPitchFontSize" : [NSString stringWithFormat:@"%g", 12.0],

    @"GSFontAntiAlias" : @"NO"
  };
  [defaultValues retain];

  fontCategories = @{
    @"Application Font" : @"NSUserFont",
    @"Fixed Pitch Font" : @"NSUserFixedPitchFont",
    @"System Font" : @"NSFont",
    @"Bold System Font" : @"NSBoldFont",
    @"Tool Tips Font" : @"NSToolTipsFont"
  };
  [fontCategories retain];

  return self;
}

- (void)awakeFromNib
{
  if (!view) {
    view = [[window contentView] retain];
    [view removeFromSuperview];
  }
  [window release];
  window = nil;

  exampleString = NSLocalizedStringFromTableInBundle(@"Example Text", @"Localizable", bundle, @"");
  [fontExampleTextView setText:exampleString];

  [self updateUI];
}

- (NSView *)view
{
  if (view == nil) {
    if (![NSBundle loadNibNamed:@"Fonts" owner:self]) {
      NSLog(@"Font: Could not load nib \"Fonts\", aborting.");
      return nil;
    }
  }
  return view;
}

- (NSString *)buttonCaption
{
  return NSLocalizedStringFromTableInBundle(@"Font Preferences", @"Localizable", bundle, @"");
}

- (NSImage *)buttonImage
{
  // NSLog(@"Font preferences image: %@ path: %@", image, imagePath);

  return AUTORELEASE(image);
}

// --- Action methods

- (void)updateUI
{
  NSString *fontKey;
  NSString *fontSizeKey;
  NSFont *font;

  fontKey = [fontCategories objectForKey:[fontCategoryPopUp titleOfSelectedItem]];
  if (!fontKey) {  // no selected item, bail out
    [fontNameTextField setStringValue:@"Unable to determine font type."];
    [fontExampleTextView setFont:[NSFont systemFontOfSize:12.0]];
    [view setNeedsDisplay:YES];
    return;
  }

  fontSizeKey = [NSString stringWithFormat:@"%@Size", fontKey];
  font = [NSFont fontWithName:[self _getStringDefault:fontKey]
                         size:[self _getFloatDefault:fontSizeKey]];
  //
  [fontNameTextField setFont:font];
  [fontNameTextField setStringValue:[NSString stringWithFormat:@"%@ %g point", [font displayName],
                                                               [font pointSize]]];
  //
  [fontExampleTextView setFont:font];
  //
  [enableAntiAliasingButton setIntValue:[self _getBoolDefault:@"GSFontAntiAlias"]];
  [view setNeedsDisplay:YES];
}

- (void)updateFontPanel
{
  NSString *fontKey;
  NSString *fontSizeKey;
  NSFont *font;
  NSFontManager *fontManager;

  fontKey = [fontCategories objectForKey:[fontCategoryPopUp titleOfSelectedItem]];
  fontSizeKey = [NSString stringWithFormat:@"%@Size", fontKey];

  font = [NSFont fontWithName:[self _getStringDefault:fontKey]
                         size:[self _getFloatDefault:fontSizeKey]];

  fontManager = [NSFontManager sharedFontManager];
  [fontManager setSelectedFont:font isMultiple:NO];
  if (!fontPanel) {
    fontPanel = [fontManager fontPanel:YES];
    [fontPanel setDelegate:self];
  }
}

- (IBAction)fontCategoryChanged:(id)sender
{
  [self updateUI];
  [self updateFontPanel];
}

- (IBAction)setFont:(id)sender
{
  [self updateFontPanel];
  [fontPanel makeKeyAndOrderFront:self];
}

- (IBAction)enableAntiAliasingChanged:(id)sender
{
  NSFont *font;
  NSString *fontName;
  CGFloat fontSize;

  // GS
  [self _setBoolDefault:[sender intValue] forName:@"GSFontAntiAlias"];

  // WM
  // [self setWMPreference:([sender intValue] ? @"YES" : @"NO") forKey:@"UseAntialiasedText"];

  fontName = [defaults objectForKey:@"NSBoldFont"];
  fontSize = [[defaults objectForKey:@"NSBoldFontSize"] floatValue];
  font = [NSFont fontWithName:fontName size:fontSize];
  [self setWMFont:font forKey:@"MenuTitleFont"];
  [self setWMFont:font forKey:@"WindowTitleFont"];

  fontName = [defaults objectForKey:@"NSFont"];
  fontSize = [[defaults objectForKey:@"NSFontSize"] floatValue];
  font = [NSFont fontWithName:fontName size:fontSize];
  [self setWMFont:font forKey:@"MenuTextFont"];
  [self setWMFont:[NSFont fontWithName:fontName size:fontSize - 3.0] forKey:@"IconTitleFont"];
  [self setWMFont:[NSFont fontWithName:fontName size:fontSize * 2.0] forKey:@"LargeDisplayFont"];

  [[NSDistributedNotificationCenter defaultCenter]
      postNotificationName:WMDidChangeAppearanceSettingsNotification
                    object:@"GSWorkspaceNotification"];

  [self updateUI];
}

// --- Class methods

- (void)changeFont:(id)sender
{
  NSString *fontName, *fontKey;
  CGFloat fontSize;
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFont *font;

  font = [fontManager convertFont:[fontExampleTextView font]];
  fontName = [font fontName];
  fontSize = [font pointSize];
  fontKey = [fontCategories objectForKey:[fontCategoryPopUp titleOfSelectedItem]];

  if ([fontKey isEqualToString:@"NSUserFont"]) {  // Application
    // NSUserFont, NSUserFontSize=12
    [self _setStringDefault:fontName forName:@"NSUserFont"];
    [self _setFloatDefault:fontSize  forName:@"NSUserFontSize"];
  } else if ([fontKey isEqualToString:@"NSUserFixedPitchFont"]) {  // Fixed Pitch
    // NSUserFixedPitchFont, NSUserFixedPitchFontSize
    [self _setStringDefault:fontName forName:@"NSUserFixedPitchFont"];
    [self _setFloatDefault:fontSize forName:@"NSUserFixedPitchFontSize"];
  } else if ([fontKey isEqualToString:@"NSFont"]) {  // System
    // NSFont, NSFontSize=12
    [self _setStringDefault:fontName forName:@"NSFont"];
    [self _setFloatDefault:fontSize forName:@"NSFontSize"];
    // NSMenuFont, NSMenuFontSize=12
    [self _setStringDefault:fontName forName:@"NSMenuFont"];
    [self _setFloatDefault:fontSize forName:@"NSMenuFontSize"];
    // NSMessageFont, NSMessageFontSize = NSFontSize+2
    [self _setStringDefault:fontName forName:@"NSMessageFont"];
    [self _setFloatDefault:fontSize + 2.0 forName:@"NSMessageFontSize"];
    // NSControlContentFont, NSControlContentFontSize=12
    [self _setStringDefault:fontName forName:@"NSControlContentFont"];
    [self _setFloatDefault:fontSize forName:@"NSControlContentFontSize"];
    // NSLabelFont, NSLabelFontSize=12
    [self _setStringDefault:fontName forName:@"NSLabelFont"];
    [self _setFloatDefault:fontSize forName:@"NSLabelFontSize"];
    // NSMiniFontSize=9, NSSmallFontSize=11
    [self _setFloatDefault:fontSize - 3.0 forName:@"NSMiniFontSize"];
    [self _setFloatDefault:fontSize - 2.0 forName:@"NSSmallFontSize"];
    // WM
    [self setWMFont:font forKey:@"MenuTextFont"];
    [self setWMFont:[NSFont fontWithName:fontName size:fontSize - 3.0] forKey:@"IconTitleFont"];
    [self setWMFont:[NSFont fontWithName:fontName size:fontSize * 2.0] forKey:@"LargeDisplayFont"];
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:WMDidChangeAppearanceSettingsNotification
                      object:@"GSWorkspaceNotification"];
  } else if ([fontKey isEqualToString:@"NSBoldFont"]) {  // Bold System
    // NSBoldFont, NSBoldFontSize=12
    [self _setStringDefault:fontName forName:@"NSBoldFont"];
    [self _setFloatDefault:fontSize forName:@"NSBoldFontSize"];
    // NSTitleBarFont, NSTitleBarFontSize=12
    [self _setStringDefault:fontName forName:@"NSTitleBarFont"];
    [self _setFloatDefault:fontSize forName:@"NSTitleBarFontSize"];
    // NSMenuBarFont
    [self _setStringDefault:fontName forName:@"NSMenuBarFont"];
    // NSPaletteFont, NSPaletteFontSize=12
    [self _setStringDefault:fontName forName:@"NSPaletteFont"];
    [self _setFloatDefault:fontSize forName:@"NSPaletteFontSize"];
    // WM
    [self setWMFont:font forKey:@"MenuTitleFont"];
    [self setWMFont:font forKey:@"WindowTitleFont"];
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:WMDidChangeAppearanceSettingsNotification
                      object:@"GSWorkspaceNotification"];
  } else if ([fontKey isEqualToString:@"NSToolTipsFont"]) {  // Tool Tips
    // NSToolTipsFont, NSToolTipsFontSize=11
    [self _setStringDefault:fontName forName:@"NSToolTipsFont"];
    [self _setFloatDefault:fontSize forName:@"NSToolTipsFontSize"];
  }

  [defaults synchronize];
  [self updateUI];
  [[NSDistributedNotificationCenter defaultCenter]
      postNotificationName:@"NXTSystemFontPreferencesDidChangeNotification"
                    object:@"Preferences"];
}

@end  // Font
