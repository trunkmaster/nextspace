/*
  Copyright (C) 2015 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <Foundation/NSString.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSGraphics.h>

#include "Terminal.h"
#import "Defaults.h"

@implementation Defaults

static Defaults *shared = nil;

+ shared
{
  if (shared == nil)
    {
      shared = [self new];
    }
  return shared;
}

+ (void)initialize
{
  if (!ud)
    {
      ud = [NSUserDefaults standardUserDefaults];
      [self readWindowDefaults];
      // [self readColorsDefaults];
      
      [self readTitleBarDefaults];
      [self readDisplayDefaults];
      [self readShellDefaults];
      [self readLinuxDefaults];
      [self readStartupDefaults];
    }
}

- (id)initWithFile:(NSString *)path
{
  self = [super init];

  filePath = path;
  defaults = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
  
  [self readWindowDefaults];
  // [self readColorsDefaults] called by -readWindowDefaults
      
  [self readTitleBarDefaults];
  [self readDisplayDefaults];
  [self readShellDefaults];
  [self readLinuxDefaults];
  [self readStartupDefaults];
}

- (BOOL)synchronize
{
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
  
  windowWidth = [defaults integerForKey:WindowWidthKey];
  windowHeight = [defaults integerForKey:WindowHeightKey];
  if (windowWidth <= 0) windowWidth = DEFAULT_COLUMNS;
  if (windowHeight <= 0) windowHeight = DEFAULT_LINES;
  
  windowCloseBehavior = [defaults integerForKey:WindowCloseBehaviorKey];
  // addYBorders = [defaults boolForKey:AddYBordersKey];
  addYBorders = NO;

  // Normal font
  size = [defaults floatForKey:TerminalFontSizeKey];
  s = [defaults stringForKey:TerminalFontKey];
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
- (int)windowHeight
{
  return windowHeight;
}
- (WindowCloseBehavior)windowCloseBehavior // 'When Shell Exits'
{
  return windowCloseBehavior;
}
- (NSFont *)terminalFont
{
  NSFont *f = [terminalFont screenFont];
  
  if (f)
    return f;
   
  return terminalFont;
}
- (NSSize)characterCellSizeForFont:(NSFont *)font
{
  NSSize s;

  if (!font)
    {
      font = [self terminalFont];
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
  titleBarElements = [defaults integerForKey:TitleBarElementsMaskKey];
  if (!titleBarElements)
    {
      titleBarElements = TitleBarShellPath |
                         TitleBarDeviceName |
                         TitleBarWindowSize;
    }
  titleBarCustomTitle = [defaults stringForKey:TitleBarCustomTitleKey];
  if (!titleBarCustomTitle)
    {
      titleBarCustomTitle = @"Terminal";
    }
}
- (NSUInteger)titleBarElementsMask
{
  return titleBarElements;
}
- (NSString *)customTitle
{
  return titleBarCustomTitle;
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
  characterSet=[[defaults stringForKey:CharacterSetKey] retain];
  if (!characterSet)
    {
      characterSet = @"utf-8";
    }
  
  useMultiCellGlyphs = [defaults boolForKey:UseMultiCellGlyphsKey];
  
  commandAsMeta = [defaults boolForKey:CommandAsMetaKey];
  
  doubleEscape = [defaults boolForKey:DoubleEscapeKey];
}
- (NSString *)characterSet
{
  return characterSet;
}
- (BOOL)commandAsMeta
{
  return commandAsMeta;
}
- (BOOL)doubleEscape
{
  return doubleEscape;
}
- (BOOL)useMultiCellGlyphs
{
  return useMultiCellGlyphs;
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

- (void)readColorsDefaults
{
  NSDictionary *desc;
  
  blackOnWhite = [defaults boolForKey:BlackOnWhiteKey];

  cursorStyle = [defaults integerForKey:CursorStyleKey];

  if (!(desc = [defaults objectForKey:CursorColorKey]))
    desc = [self descriptionFromColor:[NSColor grayColor]];
  cursorColor = [[self colorFromDescription:desc] retain];

  if (!(desc = [defaults objectForKey:WindowBGColorKey]))
    desc = [self descriptionFromColor:[NSColor whiteColor]];
  windowBGColor = [[self colorFromDescription:desc] retain];
  
  if (!(desc = [defaults objectForKey:SelectionBGColorKey]))
    desc = [self descriptionFromColor:[NSColor lightGrayColor]];
  windowSELColor = [[self colorFromDescription:desc] retain];

  if (!(desc = [defaults objectForKey:TextNormalColorKey]))
    desc = [self descriptionFromColor:[NSColor blackColor]];
  normalTextColor = [[self colorFromDescription:desc] retain];

  if (!(desc = [defaults objectForKey:TextBoldColorKey]))
    desc = [self descriptionFromColor:[NSColor blackColor]];
  boldTextColor = [[self colorFromDescription:desc] retain];

  if (!(desc = [defaults objectForKey:TextBlinkColorKey]))
    desc = [self descriptionFromColor:[NSColor yellowColor]];
  blinkTextColor = [[self colorFromDescription:desc] retain];

  if (!(desc = [defaults objectForKey:TextInverseBGColorKey]))
    desc = [self descriptionFromColor:[NSColor darkGrayColor]];
  inverseBGColor = [[self colorFromDescription:desc] retain];
  
  if (!(desc = [defaults objectForKey:TextInverseFGColorKey]))
    desc = [self descriptionFromColor:[NSColor whiteColor]];
  inverseFGColor = [[self colorFromDescription:desc] retain];
    
  useBoldTerminalFont = [defaults boolForKey:TerminalFontUseBoldKey];
  
  // Try to find bold version of normal font
  if (boldTerminalFont) [boldTerminalFont release];
  boldTerminalFont = [self boldTerminalFontForFont:[self terminalFont]];
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
- (NSColor *)cursorColor
{
  return cursorColor;
}

- (NSColor *)windowBackgroundColor
{
  return windowBGColor;
}
- (NSColor *)windowSelectionColor
{
  return windowSELColor;
}
// TODO:
- (BOOL)isCursorBlinking
{
  return NO;
}
- (NSColor *)textNormalColor
{
  return normalTextColor;
}
- (NSColor *)textBoldColor
{
  return boldTextColor;
}
- (NSColor *)textBlinkColor
{
  return blinkTextColor;
}
- (NSColor *)textInverseBackground
{
  return inverseBGColor;
}
- (NSColor *)textInverseForeground
{
  return inverseFGColor;
}
- (BOOL)useBoldTerminalFont
{
  return useBoldTerminalFont;
}
- (NSFont *)boldTerminalFontForFont:(NSFont *)font
{
  NSFont *boldFont = nil;
  
  if (font != nil && useBoldTerminalFont)
    {
      NSString *s;
      float    size;

      s = [NSString stringWithFormat:@"%@-Bold", [font fontName]];
      size = [font pointSize];
      boldFont = [[[NSFont fontWithName:s size:size] screenFont] retain];
      NSLog(@"Found Bold font: %@ [%@]", s, boldFont);
    }
  else
    {
      boldFont = (font != nil) ? font : [self terminalFont];
    }

  return boldFont;
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
- (void)checkDisplayDefaults
{
  if ([defaults objectForKey:ScrollBackEnabledKey] == nil)
    [defaults setBool:YES forKey:ScrollBackEnabledKey];
    
  if ([defaults objectForKey:ScrollBackUnlimitedKey] == nil)
    [defaults setBool:NO forKey:ScrollBackUnlimitedKey];
  
  if ([defaults objectForKey:ScrollBackLinesKey] == nil)
    [defaults setInteger:256 forKey:ScrollBackLinesKey];
  
  if ([defaults objectForKey:ScrollBottomOnInputKey] == nil)
    [defaults setBool:YES forKey:ScrollBottomOnInputKey];
}
- (void)readDisplayDefaults
{
  [self checkDisplayDefaults];
  scrollBackEnabled = [defaults boolForKey:ScrollBackEnabledKey];
  
  if (scrollBackEnabled == NO)
    {
      scrollBackLines = 0;
      return;
    }

  scrollBackUnlimited = [defaults boolForKey:ScrollBackUnlimitedKey];
  
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
      scrollBackLines = [defaults integerForKey:ScrollBackLinesKey];
      if (scrollBackLines <= 0) scrollBackLines = 256;
    }

  scrollBottomOnInput = [defaults boolForKey:ScrollBottomOnInputKey];
}

- (int)scrollBackLines
{
  return scrollBackLines;
}
- (BOOL)scrollBackEnabled
{
  return scrollBackEnabled;
}
- (BOOL)scrollBackUnlimited
{
  if (scrollBackEnabled == NO)
    return NO;
  
  return scrollBackUnlimited;
}
- (BOOL)scrollBottomOnInput
{
  return scrollBottomOnInput;
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
  shell = [defaults stringForKey:ShellKey];
  if (!shell && getenv("SHELL"))
    {
      shell = [NSString stringWithCString: getenv("SHELL")];
    }
  if (!shell)
    {
      shell = @"/bin/sh";
    }
  shell = [shell retain];
  
  loginShell = [defaults boolForKey:LoginShellKey];
}
- (NSString *)shell
{
  return shell;
}
- (BOOL)loginShell
{
  return loginShell;
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
  startupAction = [defaults integerForKey:StartupActionKey];
  if (startupAction == 0)
    startupAction = 3;

  startupFile = [defaults objectForKey:StartupFileKey];
  hideOnAutolaunch = [defaults boolForKey:HideOnAutolaunchKey];
}
- (StartupAction)startupAction
{
  return startupAction;
}
- (NSString *)startupFile
{
  return startupFile;
}
- (BOOL)hideOnAutolaunch
{
  return hideOnAutolaunch;
}
@end
