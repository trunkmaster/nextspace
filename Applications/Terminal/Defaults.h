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
*/

#import <Foundation/Foundation.h>

// NSUserDefaults *ud;

@class NSColor, NSFont;

@interface Defaults : NSObject <NSCopying>
{
  NSString *filePath;
  id defaults;  // NSUserDefaults or NSMutableDictionary
}

+ shared;
+ (NSString *)sessionsDirectory;

- (id)initEmpty;
- (id)initWithFile:(NSString *)filePath;
- (id)initWithDefaults:(id)def;

- (NSDictionary *)dictionaryRep;
- (id)defaults;

- (BOOL)writeToFile:(NSString *)fileName atomically:(BOOL)atom;
- (BOOL)synchronize;

//-----------------------------------------------------------------------------
// Values
//-----------------------------------------------------------------------------
- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;

- (float)floatForKey:(NSString *)key;
- (void)setFloat:(float)value forKey:(NSString *)key;

- (NSInteger)integerForKey:(NSString *)key;
- (void)setInteger:(NSInteger)value forKey:(NSString *)key;

- (BOOL)boolForKey:(NSString *)key;
- (void)setBool:(BOOL)value forKey:(NSString *)key;

- (NSString *)stringForKey:(NSString *)key;

@end

// Used for per-window setting preferences ("Set Window" button).
extern NSString *TerminalPreferencesDidChangeNotification;

//----------------------------------------------------------------------------
// Window
//---
#define DEFAULT_COLUMNS 80
#define DEFAULT_LINES 25
#define MIN_COLUMNS 40
#define MIN_LINES 4

extern NSString *WindowCloseBehaviorKey;
extern NSString *WindowHeightKey;
extern NSString *WindowWidthKey;
extern NSString *AddYBordersKey;
extern NSString *TerminalFontKey;
extern NSString *TerminalFontSizeKey;

typedef enum {
  WindowCloseAlways = 0,
  WindowCloseOnCleanExit = 1,
  WindowCloseNever = 2
} WindowCloseBehavior;

@interface Defaults (Window)
+ (NSSize)characterCellSizeForFont:(NSFont *)font;
+ (NSFont *)boldTerminalFontForFont:(NSFont *)font;

- (int)windowWidth;
- (void)setWindowWidth:(int)width;
- (int)windowHeight;
- (void)setWindowHeight:(int)width;
- (WindowCloseBehavior)windowCloseBehavior;  // 'When Shell Exits'
- (void)setWindowCloseBehavior:(WindowCloseBehavior)behavior;
- (NSFont *)terminalFont;
- (void)setTerminalFont:(NSFont *)font;
@end

//----------------------------------------------------------------------------
// Title Bar
//---
extern NSString *TitleBarElementsMaskKey;
extern NSString *TitleBarCustomTitleKey;

extern const NSUInteger TitleBarCustomTitle;
extern const NSUInteger TitleBarShellPath;
extern const NSUInteger TitleBarDeviceName;
extern const NSUInteger TitleBarFileName;
extern const NSUInteger TitleBarWindowSize;
extern const NSUInteger TitleBarXTermTitle;

@interface Defaults (TitleBar)
- (NSUInteger)titleBarElementsMask;
- (void)setTitleBarElementsMask:(NSUInteger)mask;
- (NSString *)customTitle;
- (void)setCustomTitle:(NSString *)title;
@end
//----------------------------------------------------------------------------
// Linux Emulation
//---
extern NSString *CharacterSetKey;
extern NSString *UseMultiCellGlyphsKey;
extern NSString *AlternateAsMetaKey;
extern NSString *DoubleEscapeKey;

@interface Defaults (Linux)
- (NSString *)characterSet;
- (void)setCharacterSet:(NSString *)cSet;
- (BOOL)alternateAsMeta;
- (void)setAlternateAsMeta:(BOOL)yn;
- (BOOL)doubleEscape;
- (void)setDoubleEscape:(BOOL)yn;
- (BOOL)useMultiCellGlyphs;
- (void)setUseMultiCellGlyphs:(BOOL)yn;
@end
//----------------------------------------------------------------------------
// Selection
//---
extern NSString *WordCharactersKey;

@interface Defaults (Selection)
- (NSString *)wordCharacters;
- (void)setWordCharacters:(NSString *)characters;
@end

//----------------------------------------------------------------------------
// Colors
//---
extern NSString *BlackOnWhiteKey;
extern NSString *CursorStyleKey;
extern NSString *CursorColorKey;

extern NSString *WindowBGColorKey;
extern NSString *SelectionBGColorKey;
extern NSString *TextNormalColorKey;
extern NSString *TextBlinkColorKey;
extern NSString *TextBoldColorKey;
extern NSString *TextInverseBGColorKey;
extern NSString *TextInverseFGColorKey;

extern NSString *TerminalFontUseBoldKey;

@interface Defaults (Colors)
#define CURSOR_BLOCK_INVERT 0
#define CURSOR_BLOCK_STROKE 1
#define CURSOR_BLOCK_FILL 2
#define CURSOR_LINE 3

+ (NSDictionary *)descriptionFromColor:(NSColor *)color;
+ (NSColor *)colorFromDescription:(NSDictionary *)desc;

// - (const float *)brightnessForIntensities;
// - (const float *)saturationForIntensities;
- (int)cursorStyle;
- (void)setCursorStyle:(int)style;
- (NSColor *)cursorColor;
- (void)setCursorColor:(NSColor *)color;
- (NSColor *)windowBackgroundColor;
- (void)setWindowBackgroundColor:(NSColor *)color;
- (NSColor *)windowSelectionColor;
- (void)setWindowSelectionColor:(NSColor *)color;
- (BOOL)isCursorBlinking;
- (void)setCursorBlinking:(BOOL)yn;
- (NSColor *)textNormalColor;
- (void)setTextNormalColor:(NSColor *)color;
- (NSColor *)textBoldColor;
- (void)setTextBoldColor:(NSColor *)color;
- (NSColor *)textBlinkColor;
- (void)setTextBlinklColor:(NSColor *)color;
- (NSColor *)textInverseBackground;
- (void)setTextInverseBackground:(NSColor *)color;
- (NSColor *)textInverseForeground;
- (void)setTextInverseForeground:(NSColor *)color;
- (BOOL)useBoldTerminalFont;
- (void)setUseBoldTerminalFont:(BOOL)yn;
@end

//----------------------------------------------------------------------------
// Display
//---
extern NSString *ScrollBackLinesKey;
extern NSString *ScrollBackEnabledKey;
extern NSString *ScrollBackUnlimitedKey;
extern NSString *ScrollBottomOnInputKey;

@interface Defaults (Display)
- (int)scrollBackLines;
- (void)setScrollBackLines:(int)lines;
- (BOOL)scrollBackEnabled;
- (void)setScrollBackEnabled:(BOOL)yn;
- (BOOL)scrollBackUnlimited;
- (void)setScrollBackUnlimited:(BOOL)yn;
- (BOOL)scrollBottomOnInput;
- (void)setScrollBottomOnInput:(BOOL)yn;
@end

//----------------------------------------------------------------------------
// Activity Monitor
//---
extern NSString *ActivityMonitorEnabledKey;
extern NSString *IsBackgroundProcessesCleanKey;
extern NSString *CleanCommandsKey;

@interface Defaults (ActivityMonitor)
- (BOOL)isActivityMonitorEnabled;
- (void)setIsActivityMonitorEnabled:(BOOL)yn;
- (BOOL)isBackgroundProcessesClean;
- (void)setIsBackgroundProcessesClean:(BOOL)yn;
- (NSArray *)cleanCommands;
- (void)setCleanCommands:(NSArray *)list;
@end

//----------------------------------------------------------------------------
// Shell
//---
extern NSString *ShellKey;
extern NSString *LoginShellKey;

@interface Defaults (Shell)
- (NSString *)shell;
- (void)setShell:(NSString *)sh;
- (BOOL)loginShell;
- (void)setLoginShell:(BOOL)yn;
@end

//----------------------------------------------------------------------------
// Startup
//---
extern NSString *StartupActionKey;
extern NSString *StartupFileKey;
extern NSString *HideOnAutolaunchKey;

typedef enum { OnStartDoNothing = 1, OnStartOpenFile = 2, OnStartCreateShell = 3 } StartupAction;

@interface Defaults (Startup)
- (StartupAction)startupAction;
- (void)setStartupAction:(StartupAction)action;
- (NSString *)startupFile;
- (void)setStartupFile:(NSString *)filePath;
- (BOOL)hideOnAutolaunch;
- (void)setHideOnAutolaunch:(BOOL)yn;
@end

extern NSString *PreserveReadlineWordMovementKey;
extern NSString *SwallowSuperKeyKey;
extern NSString *SuperKeyKeycode;

@interface Defaults (Keyboard)
- (BOOL)swallowSuperKey;
- (BOOL)preserveReadlineWordMovement;
- (unsigned short)superKeyKeycode;
@end
