/*
  Copyright (C) 2015 Sergii Stoian <stoyan255@ukr.net>

  Defaults can provide access to user defaults file (~/L/P/Terminal.plist) and 
  arbitrary file.
  Access to NSUserDefaults file:
  	[Defaults shared];
  Acess to arbitrary file:
  	[[Defaults alloc] initWithFile:"~/path/to/filename"];

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <Foundation/NSString.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSGraphics.h>

#import "Terminal.h"
#import "Defaults.h"

@implementation Defaults

static Defaults *shared = nil;

// Get Defaults instance with NSUserDefaults preferences.
+ shared
{
  if (shared == nil)
    {
      shared = [self new];
    }
  return shared;
}

// Store NSUserDefaults in 'defaults' ivar
- (id)init
{
  self = [super init];

  filePath = nil;
  defaults = [NSUserDefaults standardUserDefaults];
  
  [self readWindowDefaults]; // [self readColorsDefaults];
  [self readTitleBarDefaults];
  [self readDisplayDefaults];
  [self readShellDefaults];
  [self readLinuxDefaults];
  [self readStartupDefaults];

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
  self = [super init];

  filePath = path;
  defaults = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
  
  [self readWindowDefaults]; // [self readColorsDefaults]
  [self readTitleBarDefaults];
  [self readDisplayDefaults];
  [self readShellDefaults];
  [self readLinuxDefaults];
  [self readStartupDefaults];

  return self;
}

- (id)initWithDefaults:(id)def
{
  self = [super init];
  if ([def isKindOfClass:[NSUserDefaults class]])
    {
      NSDictionary *udd = [def persistentDomainForName:@"Terminal"];
      defaults = [[NSMutableDictionary alloc] initWithDictionary:udd
                                                       copyItems:NO];
    }
  else
    {
      defaults = [def copy];
    }

  return self;
}

- (void)dealloc
{
  [defaults dealloc];
  [super dealloc];
}

- (id)copyWithZone:(NSZone*)zone
{
  Defaults *copy = [Defaults allocWithZone:zone];

  return [copy initWithDefaults:defaults];
}

- (id)defaults
{
  return defaults;
}

- (BOOL)synchronize
{
  if ([defaults isKindOfClass:[NSUserDefaults class]])
    return [defaults synchronize];
  else
    return [defaults writeToFile:filePath atomically:YES];
}

//-----------------------------------------------------------------------------
#pragma mark - Values
//-----------------------------------------------------------------------------

- (id)objectForKey:(NSString *)key
{
  return [defaults objectForKey:key];
}

- (void)setObject:(id)value
           forKey:(NSString *)key
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

  if (obj != nil && ([obj isKindOfClass:[NSString class]]
		  || [obj isKindOfClass:[NSNumber class]]))
    {
      return [obj floatValue];
    }

  return 0.0;
}

- (void)setFloat:(float)value
          forKey:(NSString*)key
{
  [self setObject:[NSNumber numberWithFloat:value] forKey:key];
}

- (NSInteger)integerForKey:(NSString *)key
{
  id obj = [self objectForKey:key];

  if (obj != nil && ([obj isKindOfClass:[NSString class]]
		  || [obj isKindOfClass:[NSNumber class]]))
    {
      return [obj integerValue];
    }

  return -1;
}

- (void)setInteger:(NSInteger)value
            forKey:(NSString *)key
{
  [self setObject:[NSNumber numberWithInteger:value] forKey:key];
}

- (BOOL)boolForKey:(NSString*)key
{
  id obj = [self objectForKey:key];

  if (obj != nil && ([obj isKindOfClass:[NSString class]]
		  || [obj isKindOfClass:[NSNumber class]]))
    {
      return [obj boolValue];
    }

  return NO;
}

- (void)setBool:(BOOL)value
         forKey:(NSString*)key
{
  if (value == YES)
    {
      [self setObject:@"YES" forKey:key];
    }
  else
    {
      [self setObject:@"NO" forKey:key];
    }
}

- (NSString *)stringForKey:(NSString*)key
{
  return [defaults objectForKey:key];
}

@end

NSString *
TerminalPreferencesDidChangeNotification = @"TerminalPreferencesDidChange";

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
static WindowCloseBehavior windowCloseBehavior;
static int windowWidth, windowHeight;
static BOOL addYBorders;
static NSFont *terminalFont;
//---
@implementation Defaults (Window)
- (void)readWindowDefaults
{
  NSString *s;
  float    size;
  
  windowWidth = [self integerForKey:WindowWidthKey];
  windowHeight = [self integerForKey:WindowHeightKey];
  if (windowWidth <= 0) windowWidth = DEFAULT_COLUMNS;
  if (windowHeight <= 0) windowHeight = DEFAULT_LINES;
  
  windowCloseBehavior = [self integerForKey:WindowCloseBehaviorKey];
  // addYBorders = [defaults boolForKey:AddYBordersKey];
  addYBorders = NO;

  // Normal font
  size = [self floatForKey:TerminalFontSizeKey];
  s = [self stringForKey:TerminalFontKey];
  if (!s)
    {
      terminalFont = [[NSFont userFixedPitchFontOfSize:size] retain];
    }
  else
    {
      terminalFont = [[NSFont fontWithName:s size:size] retain];
      if (!terminalFont)
        {
          terminalFont = [[NSFont userFixedPitchFontOfSize:size] retain];
        }
    }
  
  // Try to find bold version of normal font
  [self readColorsDefaults];
}
- (int)windowWidth
{
  return windowWidth;
}
- (void)setWindowWidth:(int)width
{
  [self setInteger:width forKey:WindowWidthKey];
}
- (int)windowHeight
{
  return windowHeight;
}
- (void)setWindowHeight:(int)height
{
  [self setInteger:height forKey:WindowHeightKey];
}
- (WindowCloseBehavior)windowCloseBehavior // 'When Shell Exits'
{
  return windowCloseBehavior;
}
- (void)setWindowCloseBehavior:(WindowCloseBehavior)behavior
{
  [self setInteger:behavior forKey:WindowCloseBehaviorKey];
}
- (NSFont *)terminalFont
{
  NSFont *f = [terminalFont screenFont];
  
  if (f)
    return f;
   
  return terminalFont;
}
- (void)setTerminalFont:(NSFont *)font
{
  [self setObject:[font fontName] forKey:TerminalFontKey];
  [self setInteger:(int)[font pointSize] forKey:TerminalFontSizeKey];
}
+ (NSSize)characterCellSizeForFont:(NSFont *)font
{
  NSSize s;

  if (!font)
    {
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

@end

//----------------------------------------------------------------------------
// Title Bar
//---
NSString *TitleBarElementsMaskKey = @"TitleBarElementsMask";
NSString *TitleBarCustomTitleKey = @"TitleBarCustomTitle";

const NSUInteger TitleBarCustomTitle = 1<<0;
const NSUInteger TitleBarShellPath   = 1<<1;
const NSUInteger TitleBarDeviceName  = 1<<2;
const NSUInteger TitleBarFileName    = 1<<3;
const NSUInteger TitleBarWindowSize  = 1<<4;

static NSUInteger titleBarElements;
static NSString   *titleBarCustomTitle;

@implementation Defaults (TitleBar)
- (void)readTitleBarDefaults
{
  titleBarElements = [self integerForKey:TitleBarElementsMaskKey];
  if (!titleBarElements)
    {
      titleBarElements = TitleBarShellPath |
                         TitleBarDeviceName |
                         TitleBarWindowSize;
    }
  titleBarCustomTitle = [self stringForKey:TitleBarCustomTitleKey];
  if (!titleBarCustomTitle)
    {
      titleBarCustomTitle = @"Terminal";
    }
}
- (NSUInteger)titleBarElementsMask
{
  return titleBarElements;
}
- (void)setTitleBarElementsMask:(NSUInteger)mask
{
  [self setInteger:mask forKey:TitleBarElementsMaskKey];
  titleBarElements = mask;
}
- (NSString *)customTitle
{
  return titleBarCustomTitle;
}
- (void)setCustomTitle:(NSString *)title
{
  [self setObject:title forKey:TitleBarCustomTitleKey];
  titleBarCustomTitle = [self objectForKey:TitleBarCustomTitleKey];
}
@end

//----------------------------------------------------------------------------
// Linux Emulation
//---
NSString *CharacterSetKey  = @"Linux_CharacterSet";
NSString *UseMultiCellGlyphsKey = @"UseMultiCellGlyphs";
NSString *CommandAsMetaKey = @"CommandAsMeta";
NSString *DoubleEscapeKey  = @"DoubleEscape";
//---
static BOOL commandAsMeta,doubleEscape;
static NSString *characterSet;
static BOOL useMultiCellGlyphs;
//---
@implementation Defaults (Linux)
- (void)readLinuxDefaults
{
  characterSet = [[self stringForKey:CharacterSetKey] retain];
  if (!characterSet)
    {
      characterSet = @"utf-8";
    }
  
  useMultiCellGlyphs = [self boolForKey:UseMultiCellGlyphsKey];
  
  commandAsMeta = [self boolForKey:CommandAsMetaKey];
  
  doubleEscape = [self boolForKey:DoubleEscapeKey];
}
- (NSString *)characterSet
{
  return characterSet;
}
- (void)setCaharacterSet:(NSString *)cSet
{
  if (characterSet) [characterSet release];
  
  if (!cSet)
    cSet = @"utf-8";
    
  [self setObject:cSet forKey:CharacterSetKey];
  cSet = [self objectForKey:CharacterSetKey];
}
- (BOOL)commandAsMeta
{
  return commandAsMeta;
}
- (void)setCommandAsMeta:(BOOL)yn
{
  [self setBool:yn forKey:CommandAsMetaKey];
  commandAsMeta = yn;
}
- (BOOL)doubleEscape
{
  return doubleEscape;
}
- (void)setDoubleEscape:(BOOL)yn
{
  [self setBool:yn forKey:DoubleEscapeKey];
  doubleEscape = yn;
}
- (BOOL)useMultiCellGlyphs
{
  return useMultiCellGlyphs;
}
- (void)setUseMultiCellGlyphs:(BOOL)yn
{
  [self setBool:yn forKey:UseMultiCellGlyphsKey];
  useMultiCellGlyphs = yn;
}
@end

//----------------------------------------------------------------------------
// Colors
//---
NSString *CursorColorRKey = @"CursorColorR";
NSString *CursorColorGKey = @"CursorColorG";
NSString *CursorColorBKey = @"CursorColorB";
NSString *CursorColorAKey = @"CursorColorA";

NSString *BlackOnWhiteKey = @"BlackOnWhite";
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
static BOOL blackOnWhite;
static int cursorStyle;
static NSColor *cursorColor;

static NSColor *windowBGColor;
static NSColor *windowSELColor;
static NSColor *normalTextColor;
static NSColor *boldTextColor;
static NSColor *blinkTextColor;
static NSColor *inverseBGColor;
static NSColor *inverseFGColor;

static float brightness[3] = {0.6,0.8,1.0};
static float saturation[3] = {1.0,1.0,0.75};

static BOOL useBoldTerminalFont;
static NSFont *boldTerminalFont;
//---
@implementation Defaults (Colors)
// Utility
+ (NSDictionary *)descriptionFromColor:(NSColor *)color
{
  NSColor  *rgbColor;
  NSNumber *redComponent;
  NSNumber *greenComponent;
  NSNumber *blueComponent;
  NSNumber *alphaComponent;

  rgbColor =  [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  
  redComponent = [NSNumber numberWithFloat:[rgbColor redComponent]];
  greenComponent = [NSNumber numberWithFloat:[rgbColor greenComponent]];
  blueComponent = [NSNumber numberWithFloat:[rgbColor blueComponent]];
  alphaComponent = [NSNumber numberWithFloat:[rgbColor alphaComponent]];

  return [NSDictionary dictionaryWithObjectsAndKeys:
                         redComponent, @"Red",
                       greenComponent, @"Green",
                       blueComponent,  @"Blue",
                       alphaComponent, @"Alpha",
                       nil];
}
+ (NSColor *)colorFromDescription:(NSDictionary *)desc
{

  return [NSColor
           colorWithCalibratedRed:[[desc objectForKey:@"Red"] floatValue]
                            green:[[desc objectForKey:@"Green"] floatValue]
                             blue:[[desc objectForKey:@"Blue"] floatValue]
                            alpha:[[desc objectForKey:@"Alpha"] floatValue]];
}
+ (NSFont *)boldTerminalFontForFont:(NSFont *)font
{
  NSFont *boldFont = nil;
  
  if (font != nil && useBoldTerminalFont)
    {
      NSString *s;
      float    size;

      s = [NSString stringWithFormat:@"%@-Bold", [font fontName]];
      size = [font pointSize];
      boldFont = [[[NSFont fontWithName:s size:size] screenFont] retain];
      // NSLog(@"Found Bold font: %@ [%@]", s, boldFont);
    }
  else
    {
      return font;
    }

  return boldFont;
}

- (void)readColorsDefaults
{
  NSDictionary *desc;
  
  blackOnWhite = [self boolForKey:BlackOnWhiteKey];

  cursorStyle = [self integerForKey:CursorStyleKey];

  if (!(desc = [defaults objectForKey:CursorColorKey]))
    desc = [Defaults descriptionFromColor:[NSColor grayColor]];
  cursorColor = [[Defaults colorFromDescription:desc] retain];

  if (!(desc = [self objectForKey:WindowBGColorKey]))
    desc = [Defaults descriptionFromColor:[NSColor whiteColor]];
  windowBGColor = [[Defaults colorFromDescription:desc] retain];
  
  if (!(desc = [self objectForKey:SelectionBGColorKey]))
    desc = [Defaults descriptionFromColor:[NSColor lightGrayColor]];
  windowSELColor = [[Defaults colorFromDescription:desc] retain];

  if (!(desc = [self objectForKey:TextNormalColorKey]))
    desc = [Defaults descriptionFromColor:[NSColor blackColor]];
  normalTextColor = [[Defaults colorFromDescription:desc] retain];

  if (!(desc = [self objectForKey:TextBoldColorKey]))
    desc = [Defaults descriptionFromColor:[NSColor blackColor]];
  boldTextColor = [[Defaults colorFromDescription:desc] retain];

  if (!(desc = [self objectForKey:TextBlinkColorKey]))
    desc = [Defaults descriptionFromColor:[NSColor yellowColor]];
  blinkTextColor = [[Defaults colorFromDescription:desc] retain];

  if (!(desc = [self objectForKey:TextInverseBGColorKey]))
    desc = [Defaults descriptionFromColor:[NSColor darkGrayColor]];
  inverseBGColor = [[Defaults colorFromDescription:desc] retain];
  
  if (!(desc = [self objectForKey:TextInverseFGColorKey]))
    desc = [Defaults descriptionFromColor:[NSColor whiteColor]];
  inverseFGColor = [[Defaults colorFromDescription:desc] retain];
    
  useBoldTerminalFont = [self boolForKey:TerminalFontUseBoldKey];
  
  // Try to find bold version of normal font
  if (boldTerminalFont) [boldTerminalFont release];
  boldTerminalFont = [Defaults boldTerminalFontForFont:[self terminalFont]];
}
- (BOOL)blackOnWhite
{
  return blackOnWhite;
}
- (const float *)brightnessForIntensities
{
  return brightness;
}
- (const float *)saturationForIntensities
{
  return saturation;
}
- (int)cursorStyle
{
  return cursorStyle;
}
- (void)setCursorStyle:(int)style
{
  [self setInteger:style forKey:CursorStyleKey];
  cursorStyle = style;
}
- (NSColor *)cursorColor
{
  return cursorColor;
}
- (void)setCursorColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color]
           forKey:CursorColorKey];
  [self readColorsDefaults];
}
- (NSColor *)windowBackgroundColor
{
  return windowBGColor;
}
- (void)setWindowBackgroundColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color]
           forKey:WindowBGColorKey];
  [self readColorsDefaults];  
}
- (NSColor *)windowSelectionColor
{
  return windowSELColor;
}
- (void)setWindowSelectionColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color]
           forKey:SelectionBGColorKey];
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
  return normalTextColor;
}
- (void)setNormalColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color]
           forKey:TextNormalColorKey];
}
- (NSColor *)textBoldColor
{
  return boldTextColor;
}
- (void)setTextBoldColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color]
           forKey:TextBoldColorKey];
}
- (NSColor *)textBlinkColor
{
  return blinkTextColor;
}
- (void)setTextBlinklColor:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color]
           forKey:TextBlinkColorKey];
}
- (NSColor *)textInverseBackground
{
  return inverseBGColor;
}
- (void)setTextInverseBackground:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color]
           forKey:TextInverseBGColorKey];
}
- (NSColor *)textInverseForeground
{
  return inverseFGColor;
}
- (void)setTextInverseForeground:(NSColor *)color
{
  [self setObject:[Defaults descriptionFromColor:color]
           forKey:TextInverseFGColorKey];
}
- (BOOL)useBoldTerminalFont
{
  return useBoldTerminalFont;
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
static BOOL scrollBackEnabled;
static BOOL scrollBackUnlimited;
static int  scrollBackLines;
static BOOL scrollBottomOnInput;
//---
@implementation Defaults (Display)
- (void)_checkDisplayDefaults
{
  if ([self objectForKey:ScrollBackEnabledKey] == nil)
    [self setBool:YES forKey:ScrollBackEnabledKey];
    
  if ([self objectForKey:ScrollBackUnlimitedKey] == nil)
    [self setBool:NO forKey:ScrollBackUnlimitedKey];
  
  if ([self objectForKey:ScrollBackLinesKey] == nil)
    [self setInteger:256 forKey:ScrollBackLinesKey];
  
  if ([self objectForKey:ScrollBottomOnInputKey] == nil)
    [self setBool:YES forKey:ScrollBottomOnInputKey];
}
- (void)readDisplayDefaults
{
  [self _checkDisplayDefaults];
  scrollBackEnabled = [self boolForKey:ScrollBackEnabledKey];
  
  if (scrollBackEnabled == NO)
    {
      scrollBackLines = 0;
      return;
    }

  scrollBackUnlimited = [self boolForKey:ScrollBackUnlimitedKey];
  
  if (scrollBackUnlimited == YES)
    {
      // TODO: now TerminalView allocates memory for to hold all lines
      // at start (-init). If caluculations is based on INT_MAX TerminalView
      // needs to allocate ~2GB of RAM. So TerminalView memory management
      // must be rewritten to lazy allocating before "Unlimited" options
      // can be used. For now it's hardocded to some reasonable value.
      // scrollBackLines =
      //   (INT_MAX-1)/([self defaultWindowWidth]*sizeof(screen_char_t));
      // fprintf(stderr, "scrollBackLines=%i\n", scrollBackLines);
      scrollBackLines = 1024;
    }
  else
    {
      scrollBackLines = [self integerForKey:ScrollBackLinesKey];
      if (scrollBackLines <= 0) scrollBackLines = 256;
    }

  scrollBottomOnInput = [self boolForKey:ScrollBottomOnInputKey];
}

- (int)scrollBackLines
{
  return scrollBackLines;
}
- (void)setScrollBackLines:(int)lines
{
  [self setInteger:lines forKey:ScrollBackLinesKey];
  scrollBackLines = lines;
}
- (BOOL)scrollBackEnabled
{
  return scrollBackEnabled;
}
- (void)setScrollBackEnabled:(BOOL)yn
{
  [self setBool:yn forKey:ScrollBackEnabledKey];
  scrollBackEnabled = yn;
}
- (BOOL)scrollBackUnlimited
{
  if (scrollBackEnabled == NO)
    return NO;
  
  return scrollBackUnlimited;
}
- (void)setScrollBackUnlimited:(BOOL)yn
{
  [self setBool:yn forKey:ScrollBackUnlimitedKey];
  scrollBackUnlimited = yn;
}
- (BOOL)scrollBottomOnInput
{
  return scrollBottomOnInput;
}
- (void)setScrollBottomOnInput:(BOOL)yn
{
  [self setBool:yn forKey:ScrollBottomOnInputKey];
  scrollBottomOnInput = yn;
}

@end

//----------------------------------------------------------------------------
// Shell
//---
NSString *ShellKey = @"Shell";
NSString *LoginShellKey = @"LoginShell";
//---
static NSString *shell;
static BOOL loginShell;
//---
@implementation Defaults (Shell)
- (void)readShellDefaults
{
  if (shell)
    {
      [shell release];
      shell = nil;
    }
  shell = [self stringForKey:ShellKey];
  if (!shell && getenv("SHELL"))
    {
      shell = [NSString stringWithCString: getenv("SHELL")];
    }
  if (!shell)
    {
      shell = @"/bin/sh";
    }
  shell = [shell retain];
  
  loginShell = [self boolForKey:LoginShellKey];
}
- (NSString *)shell
{
  return shell;
}
- (void)setShell:(NSString *)sh
{
  [self setObject:sh forKey:ShellKey];
  [self readShellDefaults];
}
- (BOOL)loginShell
{
  return loginShell;
}
- (void)setLoginShell:(BOOL)yn
{
  [self setBool:yn forKey:LoginShellKey];
  loginShell = yn;
}
@end

//----------------------------------------------------------------------------
// Startup
//---
NSString *StartupActionKey = @"StartupAction";
NSString *StartupFileKey = @"StartupFile";
NSString *HideOnAutolaunchKey = @"HideOnAutolaunch";

static StartupAction startupAction;
static NSString      *startupFile;
static BOOL          hideOnAutolaunch;

@implementation Defaults (Startup)
- (void)readStartupDefaults
{
  startupAction = [self integerForKey:StartupActionKey];
  if (startupAction == 0) startupAction = OnStartCreateShell;

  startupFile = [self objectForKey:StartupFileKey];
  hideOnAutolaunch = [self boolForKey:HideOnAutolaunchKey];
}
- (StartupAction)startupAction
{
  return startupAction;
}
- (void)setStartupAction:(StartupAction)action
{
  [self setInteger:action forKey:StartupActionKey];
  startupAction = action;
}
- (NSString *)startupFile
{
  return startupFile;
}
- (void)setStartupFile:(NSString *)path
{
  [self setObject:path forKey:StartupFileKey];
  startupFile = [self objectForKey:StartupFileKey];  
}
- (BOOL)hideOnAutolaunch
{
  return hideOnAutolaunch;
}
- (void)setHideOnAutolaunch:(BOOL)yn
{
  [self setBool:yn forKey:HideOnAutolaunchKey];
  hideOnAutolaunch = yn;
}
@end
