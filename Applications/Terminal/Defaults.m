/*
  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

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

  Defaults can provide access to user defaults file (~/L/P/Terminal.plist) and
  arbitrary file.
  Access to NSUserDefaults file:
        [Defaults shared];
  Acess to arbitrary file:
        [[Defaults alloc] initWithFile:"~/path/to/filename"];

*/

#import <Foundation/NSString.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSGraphics.h>

#import <DesktopKit/NXTAlert.h>

#import "Terminal.h"
#import "TerminalView.h"
#import "Defaults.h"

@implementation Defaults

static Defaults *shared = nil;

// Get Defaults instance with NSUserDefaults preferences.
+ shared
{
  if (shared == nil) {
    shared = [self new];
  }
  return shared;
}

+ (NSString *)sessionsDirectory
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path;
  BOOL isDir;

  // Assume that ~/Library already exists
  path = [NSString stringWithFormat:@"%@/Library/Terminal", NSHomeDirectory()];

  if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
    if (!isDir) {
      NXTRunAlertPanel(@"Session Directory",
                       @"%@ exists and not a directory.\n"
                        "Check your home directory layout",
                       @"Ok", nil, nil, path);
      return nil;
    }
  } else {
    if ([fm createDirectoryAtPath:path attributes:nil] == NO) {
      NXTRunAlertPanel(@"Session Directory",
                       @"Error occured while creating directory %@.\n"
                        "Check your home directory layout",
                       @"Ok", nil, nil, path);
      return nil;
    }
  }

  return path;
}

// Store NSUserDefaults in 'defaults' ivar
- (id)init
{
  self = [super init];

  filePath = nil;
  defaults = [NSUserDefaults standardUserDefaults];

  return self;
}

// Empty mutable dictionary for use in Preferences modules.
- (id)initEmpty
{
  self = [super init];

  filePath = nil;
  defaults = [[NSMutableDictionary alloc] init];

  return self;
}

// Get Defaults instance with custom preferences file (*.term).
// Create NSMutableDictionary and store it in 'defaults' ivar
- (id)initWithFile:(NSString *)path
{
  if (path) {
    filePath = path;
    defaults = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
  }

  if (defaults) {
    NSLog(@"Defaults: error loading file");
    return nil;
  }

  self = [super init];

  return self;
}

- (id)initWithDefaults:(id)def
{
  self = [super init];

  if ([def isKindOfClass:[NSUserDefaults class]]) {
    NSDictionary *udd = [def persistentDomainForName:@"Terminal"];
    defaults = [[NSMutableDictionary alloc] initWithDictionary:udd copyItems:NO];
  } else {
    defaults = [[NSMutableDictionary alloc] initWithDictionary:def copyItems:NO];
  }

  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  Defaults *copy = [Defaults allocWithZone:zone];

  return [copy initWithDefaults:defaults];
}

- (void)dealloc
{
  [defaults dealloc];
  [super dealloc];
}

- (NSDictionary *)dictionaryRep
{
  if ([defaults isKindOfClass:[NSUserDefaults class]]) {
    return [defaults persistentDomainForName:@"Terminal"];
  }

  return defaults;
}

- (id)defaults
{
  return defaults;
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)atom
{
  if ([defaults isKindOfClass:[NSUserDefaults class]]) {
    return [[defaults persistentDomainForName:@"Terminal"] writeToFile:path atomically:YES];
  }

  return [defaults writeToFile:path atomically:YES];
}

- (BOOL)synchronize
{
  if ([defaults isKindOfClass:[NSUserDefaults class]]) {
    return [(NSUserDefaults *)defaults synchronize];
  } else {
    return [defaults writeToFile:filePath atomically:YES];
  }
}

//-----------------------------------------------------------------------------
#pragma mark - Values
//-----------------------------------------------------------------------------

- (id)objectForKey:(NSString *)key
{
  return [defaults objectForKey:key];
}

- (void)setObject:(id)value forKey:(NSString *)key
{
  [defaults setObject:value forKey:key];
  // [self setChanged];
}

- (void)removeObjectForKey:(NSString *)key
{
  [defaults removeObjectForKey:key];
  // [self setChanged];
}

- (float)floatForKey:(NSString *)key
{
  id obj = [self objectForKey:key];

  if (obj != nil &&
      ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]])) {
    return [obj floatValue];
  }

  return 0.0;
}

- (void)setFloat:(float)value forKey:(NSString *)key
{
  [self setObject:[NSNumber numberWithFloat:value] forKey:key];
}

- (NSInteger)integerForKey:(NSString *)key
{
  id obj = [self objectForKey:key];

  if (obj != nil &&
      ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]])) {
    return [obj integerValue];
  }

  return -1;
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key
{
  [self setObject:[NSNumber numberWithInteger:value] forKey:key];
}

- (BOOL)boolForKey:(NSString *)key
{
  id obj = [self objectForKey:key];

  if (obj != nil &&
      ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]])) {
    return [obj boolValue];
  }

  return NO;
}

- (void)setBool:(BOOL)value forKey:(NSString *)key
{
  if (value == YES) {
    [self setObject:@"YES" forKey:key];
  } else {
    [self setObject:@"NO" forKey:key];
  }
}

- (NSString *)stringForKey:(NSString *)key
{
  return [defaults objectForKey:key];
}

@end

NSString *TerminalPreferencesDidChangeNotification = @"TerminalPreferencesDidChange";

//----------------------------------------------------------------------------
// Window
//---
NSString *WindowCloseBehaviorKey = @"WindowCloseBehavior";
NSString *WindowHeightKey = @"WindowHeight";
NSString *WindowWidthKey = @"WindowWidth";
NSString *AddYBordersKey = @"AddYBorders";

NSString *TerminalFontKey = @"TerminalFont";
NSString *TerminalFontSizeKey = @"TerminalFontSize";
//---
@implementation Defaults (Window)
+ (NSFont *)boldTerminalFontForFont:(NSFont *)font
{
  NSString *fName;
  float fSize;
  NSFont *boldFont;

  if (font != nil) {
    fName = [NSString stringWithFormat:@"%@-Bold", [font familyName]];
    fSize = [font pointSize];
    boldFont = [[[NSFont fontWithName:fName size:fSize] screenFont] retain];
    // NSLog(@"Found Bold font: %f [%@]", fSize, [boldFont fontName]);
  } else {
    return font;
  }

  return boldFont;
}
+ (NSSize)characterCellSizeForFont:(NSFont *)font
{
  NSSize s;

  if (!font) {
    // font = [self terminalFont];
    return NSZeroSize;
  }

  s = [font boundingRectForFont].size;
  s.width = [font advancementForGlyph:'M'].width;

  // NSLog (@"Font %@ bounding rect: %@ XHeight: %f line height: %f",
  //        [font fontName], NSStringFromSize(s),
  //        [font xHeight], [font defaultLineHeightForFont]);

  // TODO: Why this?
  // if ([Defaults useMultiCellGlyphs])
  //   {
  //     s.width = [font boundingRectForGlyph:'A'].size.width;
  //   }

  return s;
}

- (int)windowWidth
{
  NSInteger width = [self integerForKey:WindowWidthKey];

  if (width <= 0) {
    return DEFAULT_COLUMNS;
  }

  return width;
}
- (void)setWindowWidth:(int)width
{
  [self setInteger:width forKey:WindowWidthKey];
}
- (int)windowHeight
{
  NSInteger height = [self integerForKey:WindowHeightKey];

  if (height <= 0) {
    return DEFAULT_LINES;
  }

  return height;
}
- (void)setWindowHeight:(int)height
{
  [self setInteger:height forKey:WindowHeightKey];
}
- (WindowCloseBehavior)windowCloseBehavior  // 'When Shell Exits'
{
  return [self integerForKey:WindowCloseBehaviorKey];
}
- (void)setWindowCloseBehavior:(WindowCloseBehavior)behavior
{
  [self setInteger:behavior forKey:WindowCloseBehaviorKey];
}
- (NSFont *)terminalFont
{
  NSString *fName;
  float fSize;
  NSFont *screenFont;
  NSFont *terminalFont;

  fSize = [self floatForKey:TerminalFontSizeKey];
  fName = [self stringForKey:TerminalFontKey];
  if (!fSize) {
    terminalFont = [NSFont userFixedPitchFontOfSize:fSize];
  } else {
    terminalFont = [NSFont fontWithName:fName size:fSize];
    if (!terminalFont) {
      terminalFont = [NSFont userFixedPitchFontOfSize:fSize];
    }
  }

  if ((screenFont = [terminalFont screenFont])) {
    return screenFont;
  }

  return terminalFont;
}
- (void)setTerminalFont:(NSFont *)font
{
  [self setObject:[font fontName] forKey:TerminalFontKey];
  [self setInteger:(int)[font pointSize] forKey:TerminalFontSizeKey];
}

@end

//----------------------------------------------------------------------------
// Title Bar
//---
NSString *TitleBarElementsMaskKey = @"TitleBarElementsMask";
NSString *TitleBarCustomTitleKey = @"TitleBarCustomTitle";

const NSUInteger TitleBarCustomTitle = 1 << 0;
const NSUInteger TitleBarShellPath = 1 << 1;
const NSUInteger TitleBarDeviceName = 1 << 2;
const NSUInteger TitleBarFileName = 1 << 3;
const NSUInteger TitleBarWindowSize = 1 << 4;
const NSUInteger TitleBarXTermTitle = 1 << 5;

@implementation Defaults (TitleBar)
- (NSUInteger)titleBarElementsMask
{
  NSUInteger titleBarElements;

  titleBarElements = [self integerForKey:TitleBarElementsMaskKey];
  if (!titleBarElements) {
    titleBarElements =
        TitleBarShellPath | TitleBarDeviceName | TitleBarXTermTitle | TitleBarWindowSize;
  }

  return titleBarElements;
}
- (void)setTitleBarElementsMask:(NSUInteger)mask
{
  [self setInteger:mask forKey:TitleBarElementsMaskKey];
}
- (NSString *)customTitle
{
  NSString *titleBarCustomTitle;

  titleBarCustomTitle = [self stringForKey:TitleBarCustomTitleKey];
  if (!titleBarCustomTitle) {
    titleBarCustomTitle = @"Terminal";
  }
  return titleBarCustomTitle;
}
- (void)setCustomTitle:(NSString *)title
{
  [self setObject:title forKey:TitleBarCustomTitleKey];
}
@end

//----------------------------------------------------------------------------
// Linux Emulation
//---
NSString *CharacterSetKey = @"Linux_CharacterSet";
NSString *UseMultiCellGlyphsKey = @"UseMultiCellGlyphs";
NSString *AlternateAsMetaKey = @"AlternateAsMeta";
NSString *DoubleEscapeKey = @"DoubleEscape";
//---
@implementation Defaults (Linux)
- (NSString *)characterSet
{
  NSString *characterSet;

  characterSet = [self stringForKey:CharacterSetKey];
  if (!characterSet) {
    characterSet = @"UTF-8";
  }
  return characterSet;
}
- (void)setCharacterSet:(NSString *)cSet
{
  if (!cSet) {
    cSet = @"utf-8";
  }
  [self setObject:cSet forKey:CharacterSetKey];
}
- (BOOL)alternateAsMeta
{  // Don't use boolForKey: we need to return YES if option is not set.
  id obj = [self objectForKey:AlternateAsMetaKey];

  if (obj != nil &&
      ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]])) {
    return [obj boolValue];
  }

  return YES;
}
- (void)setAlternateAsMeta:(BOOL)yn
{
  [self setBool:yn forKey:AlternateAsMetaKey];
}
- (BOOL)doubleEscape
{
  return [self boolForKey:DoubleEscapeKey];
}
- (void)setDoubleEscape:(BOOL)yn
{
  [self setBool:yn forKey:DoubleEscapeKey];
}
- (BOOL)useMultiCellGlyphs
{
  return [self boolForKey:UseMultiCellGlyphsKey];
}
- (void)setUseMultiCellGlyphs:(BOOL)yn
{
  [self setBool:yn forKey:UseMultiCellGlyphsKey];
}
@end

//----------------------------------------------------------------------------
// Colors
//---
NSString *CursorStyleKey = @"CursorStyle";
NSString *CursorColorKey = @"CursorColor";

NSString *WindowBGColorKey = @"WindowBackgroundColor";
NSString *SelectionBGColorKey = @"WindowSelectionColor";
NSString *TextNormalColorKey = @"TextNormalColor";
NSString *TextBlinkColorKey = @"TextBlinkColor";
NSString *TextBoldColorKey = @"TextBoldColor";
NSString *TextInverseBGColorKey = @"TextInverseBackgroundColor";
NSString *TextInverseFGColorKey = @"TextInverseForegroundColor";

NSString *TerminalFontUseBoldKey = @"TerminalFontUseBold";
//---
// static float brightness[3] = {0.6,0.8,1.0};
// static float saturation[3] = {1.0,1.0,0.75};
//---
@implementation Defaults (Colors)
// Utility
+ (NSDictionary *)descriptionFromColor:(NSColor *)color
{
  NSColor *rgbColor;
  NSNumber *redComponent;
  NSNumber *greenComponent;
  NSNumber *blueComponent;
  NSNumber *alphaComponent;

  rgbColor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

  redComponent = [NSNumber numberWithFloat:[rgbColor redComponent]];
  greenComponent = [NSNumber numberWithFloat:[rgbColor greenComponent]];
  blueComponent = [NSNumber numberWithFloat:[rgbColor blueComponent]];
  alphaComponent = [NSNumber numberWithFloat:[rgbColor alphaComponent]];

  return @{
    @"Red" : redComponent,
    @"Green" : greenComponent,
    @"Blue" : blueComponent,
    @"Alpha" : alphaComponent
  };
}
+ (NSColor *)colorFromDescription:(NSDictionary *)desc
{
  return [NSColor colorWithCalibratedRed:[[desc objectForKey:@"Red"] floatValue]
                                   green:[[desc objectForKey:@"Green"] floatValue]
                                    blue:[[desc objectForKey:@"Blue"] floatValue]
                                   alpha:[[desc objectForKey:@"Alpha"] floatValue]];
}

// - (const float *)brightnessForIntensities
// {
//   return brightness;
// }
// - (const float *)saturationForIntensities
// {
//   return saturation;
// }
- (int)cursorStyle
{
  NSInteger style = [self integerForKey:CursorStyleKey];

  if (style < 0) {
    style = 0;
  }
  return style;
}
- (void)setCursorStyle:(int)style
{
  [self setInteger:style forKey:CursorStyleKey];
}
- (NSColor *)cursorColor
{
  NSDictionary *desc = [defaults objectForKey:CursorColorKey];

  if (!desc) {
    desc = [Defaults descriptionFromColor:[NSColor grayColor]];
  }
  return [[Defaults colorFromDescription:desc] retain];
}
- (void)setCursorColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color] forKey:CursorColorKey];
}
- (NSColor *)windowBackgroundColor
{
  NSDictionary *desc = [self objectForKey:WindowBGColorKey];

  if (!desc) {
    desc = [Defaults descriptionFromColor:[NSColor whiteColor]];
  }
  return [[Defaults colorFromDescription:desc] retain];
}
- (void)setWindowBackgroundColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color] forKey:WindowBGColorKey];
}
- (NSColor *)windowSelectionColor
{
  NSDictionary *desc = [self objectForKey:SelectionBGColorKey];

  if (!desc) {
    desc = [Defaults descriptionFromColor:[NSColor lightGrayColor]];
  }
  return [[Defaults colorFromDescription:desc] retain];
}
- (void)setWindowSelectionColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color] forKey:SelectionBGColorKey];
}
// TODO:
- (BOOL)isCursorBlinking
{
  return NO;
}
- (void)setCursorBlinking:(BOOL)yn
{
  // TODO
}
- (NSColor *)textNormalColor
{
  NSDictionary *desc = [self objectForKey:TextNormalColorKey];

  if (!desc) {
    desc = [Defaults descriptionFromColor:[NSColor blackColor]];
  }
  return [[Defaults colorFromDescription:desc] retain];
}
- (void)setTextNormalColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color] forKey:TextNormalColorKey];
}
- (NSColor *)textBoldColor
{
  NSDictionary *desc = [self objectForKey:TextBoldColorKey];

  if (!desc) {
    desc = [Defaults descriptionFromColor:[NSColor blackColor]];
  }
  return [[Defaults colorFromDescription:desc] retain];
}
- (void)setTextBoldColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color] forKey:TextBoldColorKey];
}
- (NSColor *)textBlinkColor
{
  NSDictionary *desc = [self objectForKey:TextBlinkColorKey];

  if (!desc) {
    desc = [Defaults descriptionFromColor:[NSColor yellowColor]];
  }
  return [[Defaults colorFromDescription:desc] retain];
}
- (void)setTextBlinklColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color] forKey:TextBlinkColorKey];
}
- (NSColor *)textInverseBackground
{
  NSDictionary *desc = [self objectForKey:TextInverseBGColorKey];

  if (!desc) {
    desc = [Defaults descriptionFromColor:[NSColor darkGrayColor]];
  }
  return [[Defaults colorFromDescription:desc] retain];
}
- (void)setTextInverseBackground:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color] forKey:TextInverseBGColorKey];
}
- (NSColor *)textInverseForeground
{
  NSDictionary *desc = [self objectForKey:TextInverseFGColorKey];

  if (!desc) {
    desc = [Defaults descriptionFromColor:[NSColor whiteColor]];
  }
  return [[Defaults colorFromDescription:desc] retain];
}
- (void)setTextInverseForeground:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color] forKey:TextInverseFGColorKey];
}
- (BOOL)useBoldTerminalFont
{
  return [self boolForKey:TerminalFontUseBoldKey];
}
- (void)setUseBoldTerminalFont:(BOOL)yn
{
  [self setBool:yn forKey:TerminalFontUseBoldKey];
}
@end

//----------------------------------------------------------------------------
// Display
//---
NSString *ScrollBackLinesKey = @"ScrollBackLines";
NSString *ScrollBackEnabledKey = @"ScrollBackEnabled";
NSString *ScrollBackUnlimitedKey = @"ScrollBackUnlimited";
NSString *ScrollBottomOnInputKey = @"ScrollBottomOnInput";
//---
@implementation Defaults (Display)
- (int)scrollBackLines
{
  if ([self boolForKey:ScrollBackEnabledKey] == NO) {
    return 0;
  } else if ([self boolForKey:ScrollBackUnlimitedKey] != NO) {
    return SCROLLBACK_MAX;
  } else if ([self objectForKey:ScrollBackLinesKey] == nil) {
    return SCROLLBACK_DEFAULT;
  }

  return [self integerForKey:ScrollBackLinesKey];
}
- (void)setScrollBackLines:(int)lines
{
  NSUInteger scrollBackLines;

  if ([self scrollBackEnabled] == YES) {
    scrollBackLines = lines;
    if (scrollBackLines < 0) {
      scrollBackLines = 0;
    }
  } else {  // scrollback disabled
    scrollBackLines = 0;
  }

  [self setInteger:scrollBackLines forKey:ScrollBackLinesKey];
}
- (BOOL)scrollBackEnabled
{
  if ([self objectForKey:ScrollBackEnabledKey] == nil) {
    [self setScrollBackEnabled:YES];
  }
  return [self boolForKey:ScrollBackEnabledKey];
}
- (void)setScrollBackEnabled:(BOOL)yn
{
  [self setBool:yn forKey:ScrollBackEnabledKey];
}
- (BOOL)scrollBackUnlimited
{
  if ([self scrollBackEnabled] == NO) {
    return NO;
  }
  if ([self objectForKey:ScrollBackUnlimitedKey] == nil) {
    [self setBool:NO forKey:ScrollBackUnlimitedKey];
  }
  return [self boolForKey:ScrollBackUnlimitedKey];
}
- (void)setScrollBackUnlimited:(BOOL)yn
{
  [self setBool:yn forKey:ScrollBackUnlimitedKey];
}
- (BOOL)scrollBottomOnInput
{
  if ([self objectForKey:ScrollBottomOnInputKey] == nil) {
    [self setBool:YES forKey:ScrollBottomOnInputKey];
  }
  return [self boolForKey:ScrollBottomOnInputKey];
}
- (void)setScrollBottomOnInput:(BOOL)yn
{
  [self setBool:yn forKey:ScrollBottomOnInputKey];
}

@end

//----------------------------------------------------------------------------
// Activity Monitor
//---
NSString *ActivityMonitorEnabledKey = @"ActivityMonitorEnabled";
NSString *IsBackgroundProcessesCleanKey = @"IsBackgroundProcessesClean";
NSString *CleanCommandsKey = @"CleanCommands";

@implementation Defaults (ActivityMonitor)
- (BOOL)isActivityMonitorEnabled
{
  if ([self objectForKey:ActivityMonitorEnabledKey] == nil) {
    [self setIsActivityMonitorEnabled:YES];
  }
  return [self boolForKey:ActivityMonitorEnabledKey];
}
- (void)setIsActivityMonitorEnabled:(BOOL)yn
{
  [self setBool:yn forKey:ActivityMonitorEnabledKey];
}

- (BOOL)isBackgroundProcessesClean
{
  if ([self objectForKey:IsBackgroundProcessesCleanKey] == nil) {
    [self setIsBackgroundProcessesClean:YES];
  }
  return [self boolForKey:IsBackgroundProcessesCleanKey];  
}
- (void)setIsBackgroundProcessesClean:(BOOL)yn
{
  [self setBool:yn forKey:IsBackgroundProcessesCleanKey];
}

- (NSArray *)cleanCommands
{
  if ([self objectForKey:CleanCommandsKey] == nil) {
    [self setCleanCommands:@[ @"ssh", @"telnet", @"rlogin" ]];
  }
  return [self objectForKey:CleanCommandsKey];
}
- (void)setCleanCommands:(NSArray *)list
{
  [self setObject:list forKey:CleanCommandsKey];
}
@end


//----------------------------------------------------------------------------
// Shell
//---
NSString *ShellKey = @"Shell";
NSString *LoginShellKey = @"LoginShell";
//---
@implementation Defaults (Shell)
- (NSString *)shell
{
  NSString *shell = [self stringForKey:ShellKey];

  if (!shell && getenv("SHELL")) {
    shell = [NSString stringWithCString:getenv("SHELL")];
  }
  if (!shell) {
    shell = @"/bin/sh";
  }
  return shell;
}
- (void)setShell:(NSString *)sh
{
  [self setObject:sh forKey:ShellKey];
}
- (BOOL)loginShell
{
  return [self boolForKey:LoginShellKey];
}
- (void)setLoginShell:(BOOL)yn
{
  [self setBool:yn forKey:LoginShellKey];
}
@end

//----------------------------------------------------------------------------
// Selection
//---
NSString *WordCharactersKey = @"WordCharacters";
//---
@implementation Defaults (Selection)
- (NSString *)wordCharacters
{
  return [self stringForKey:WordCharactersKey];
}
- (void)setWordCharacters:(NSString *)characters
{
  if (characters == nil) {
    characters = @"";
  }
  [self setObject:characters forKey:WordCharactersKey];
}
@end

//----------------------------------------------------------------------------
// Startup
//---
NSString *StartupActionKey = @"StartupAction";
NSString *StartupFileKey = @"StartupFile";
NSString *HideOnAutolaunchKey = @"HideOnAutolaunch";
//---
@implementation Defaults (Startup)
- (StartupAction)startupAction
{
  if ([self integerForKey:StartupActionKey] == -1) {
    [self setStartupAction:OnStartCreateShell];
  }
  return [self integerForKey:StartupActionKey];
}
- (void)setStartupAction:(StartupAction)action
{
  [self setInteger:action forKey:StartupActionKey];
}
- (NSString *)startupFile
{
  return [self objectForKey:StartupFileKey];
}
- (void)setStartupFile:(NSString *)path
{
  [self setObject:path forKey:StartupFileKey];
}
- (BOOL)hideOnAutolaunch
{
  return [self boolForKey:HideOnAutolaunchKey];
}
- (void)setHideOnAutolaunch:(BOOL)yn
{
  [self setBool:yn forKey:HideOnAutolaunchKey];
}
@end
//----------------------------------------------------------------------------
// Keyboard
// TODO: Not expressed in menu, yet
//---
// ---
// Keyboard / Readline
NSString *PreserveReadlineWordMovementKey = @"PreserveReadlineWordMovement";
NSString *SwallowSuperKeyKey = @"SwallowSuperKey";
NSString *SuperKeyKeycode = @"SuperKeyKeycode";
// ---

@implementation Defaults (Keyboard)

- (BOOL)preserveReadlineWordMovement
{
  if ([self objectForKey:PreserveReadlineWordMovementKey] == nil) {
    return NO; // default
  }
  return [self boolForKey:PreserveReadlineWordMovementKey];
}

- (BOOL)swallowSuperKey
{
  if ([self objectForKey:SwallowSuperKeyKey] == nil) {
    return NO; // default
  }
  return [self boolForKey:SwallowSuperKeyKey];
}

- (unsigned short)superKeyKeycode
{
    NSNumber *val = [self objectForKey:SuperKeyKeycode];
    if (val == nil) {
        return 133; // default
    }
    return (unsigned short)[val unsignedIntegerValue];
}


@end

