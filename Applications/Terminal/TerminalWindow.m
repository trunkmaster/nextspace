/*
  copyright 2002, 2003 Alexander Malmberg <alexander@malmberg.org>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <math.h>
#import <sys/wait.h>

#import <Foundation/NSDebug.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSString.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSWindow.h>

#import "Controller.h"
#import "Defaults.h"
#import "TerminalWindow.h"
#import "TerminalView.h"

NSString *TerminalWindowNoMoreActiveWindowsNotification=
  @"TerminalWindowNoMoreActiveWindowsNotification";

// Window
static int terminalColumns;
static int terminalRows;
static WindowCloseBehavior windowCloseBehavior;

// Title Bar
static NSUInteger titleBarElementsMask;
static NSString   *titleBarCustomTitle;

// Display
static BOOL scrollBackEnabled;
// static BOOL scrollBackUnlimited;
// static int  scrollBackLines;
// static BOOL scrollBottomOnInput;

static int    scrollerWidth;
static NSSize charCellSize;
static NSSize winContentSize;
static NSSize winMinimumSize;

@implementation TerminalWindowController

- (void)calculateSizes
{
  // Scroller
  scrollerWidth = (scrollBackEnabled==YES) ? [NSScroller scrollerWidth] : 0;

  // calc the rects for our window
  winContentSize =
    NSMakeSize(charCellSize.width  * terminalColumns + scrollerWidth + 1,
               charCellSize.height * terminalRows + 1);
  winMinimumSize =
    NSMakeSize(charCellSize.width  * MIN_COLUMNS + scrollerWidth + 1,
               charCellSize.height * MIN_LINES + 1);
  // add the borders to the size
  winContentSize.width += 8;
  winContentSize.height += 3;
  winMinimumSize.width += 8;
  winMinimumSize.height += 3;

  return;
}

- (id)_setupWindow
{
  NSRect     contentRect, windowRect;
  NSUInteger styleMask;

  // Make cache of preferences
  scrollBackEnabled = [preferences scrollBackEnabled];
  terminalRows = [preferences windowHeight];
  terminalColumns = [preferences windowWidth];
  titleBarElementsMask = [preferences titleBarElementsMask];
  titleBarCustomTitle = [preferences customTitle];

  // Sizes
  charCellSize = [Defaults characterCellSizeForFont:nil];
  [self calculateSizes];
  
  windowCloseBehavior = [preferences windowCloseBehavior];

  contentRect = NSMakeRect(0, 0, winContentSize.width, winContentSize.height);
  styleMask = (NSClosableWindowMask  | NSTitledWindowMask |
               NSResizableWindowMask | NSMiniaturizableWindowMask);
  win = [[NSWindow alloc] initWithContentRect:contentRect
                                    styleMask:styleMask
                                      backing:NSBackingStoreRetained
                                        defer:YES];
  
  if (!(self = [super initWithWindow:win])) return nil;

  windowRect = [win frame];
  winMinimumSize.width += windowRect.size.width - winContentSize.width;
  winMinimumSize.height += windowRect.size.height - winContentSize.height;
  
  [win setTitle:titleBarCustomTitle];
  [win setDelegate:self];

  [win setContentSize:winContentSize];
  [win setResizeIncrements:NSMakeSize(charCellSize.width, charCellSize.height)];
  [win setMinSize:winMinimumSize];

  hBox = [[GSHbox alloc] init];

  // Scroller
  scroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0,0,scrollerWidth,
                                                          charCellSize.height)];
  [scroller setArrowsPosition:NSScrollerArrowsMaxEnd];
  [scroller setEnabled:YES];
  [scroller setAutoresizingMask:NSViewHeightSizable];
  if (scrollBackEnabled)
    {
      [hBox addView:scroller enablingXResizing:NO];
      [scroller release];
    }

  // View
  tView = [[TerminalView alloc] initWithPrefences:preferences];
  [tView setIgnoreResize:YES];
  [tView setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable];
  [tView setScroller:scroller];
  [hBox addView:tView];
  [tView release];
  [tView setIgnoreResize:NO];
  [win makeFirstResponder:tView];

  // if ([ud boolForKey:@"AddYBorders"])
  //   [tView setBorder:4 :4];
  // else
    [tView setBorder:4 :2];

  [win setContentView:hBox];
  DESTROY(hBox);
  
  [win release];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(preferencesDidChange:)
           name:TerminalPreferencesDidChangeNotification
         object:win];
  
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(viewBecameIdle)
           name:TerminalViewBecameIdleNotification
         object:tView];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(viewBecameNonIdle)
           name:TerminalViewBecameNonIdleNotification
         object:tView];
  
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(updateTitleBar:)
           name:TerminalViewTitleDidChangeNotification
         object:tView];

  return self;
}

- init
{
  self = [super init];
  
  [self initWithStartupFile:nil];
  
  return self;
}

- initWithStartupFile:(NSString *)filePath
{
  if (filePath == nil)
    {
      preferences = [[Defaults alloc] init];
      fileName = @"Default";
    }
  else
    {
      preferences = [[Defaults alloc] initWithFile:filePath];
      fileName = [filePath lastPathComponent];
    }
  
  [self _setupWindow];

  return self;
}

- (void)dealloc
{
  NSLog(@"Window DEALLOC.");
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  // [preferences release];
  [super dealloc];
}

// --- Accessories ---
- (TerminalView *)terminalView
{
  return tView;
}

- (WindowCloseBehavior)closeBehavior
{
  return windowCloseBehavior;
}

- (Defaults *)preferences
{
  return preferences;
}

- (Defaults *)livePreferences
{
  if (livePreferences)
    return livePreferences;
  else
    return preferences;
}

// Title Bar elements
- (NSString *)shellPath
{
  return [tView shellPath];
}

- (NSString *)deviceName
{
  return [tView deviceName];
}

- (NSString *)fileName
{
  return fileName;
}

- (NSString *)windowSize
{
  return [tView windowSize];
}

// --- Notifications ---
- (void)updateTitleBar:(NSNotification *)n
{
  NSString *title;
  NSString *miniTitle = [tView shellPath];

  title = [NSString new];
  
  if (titleBarElementsMask & TitleBarShellPath)
    title = [title stringByAppendingFormat:@"%@ ", [tView shellPath]];
  
  if (titleBarElementsMask & TitleBarDeviceName)
    title = [title stringByAppendingFormat:@"(%@) ", [tView deviceName]];
  
  if (titleBarElementsMask & TitleBarWindowSize)
    title = [title stringByAppendingFormat:@"%@ ", [tView windowSize]];
  
  if (titleBarElementsMask & TitleBarCustomTitle)
    {
      if ([title length] == 0)
        {
          title = [NSString stringWithFormat:@"%@ ", titleBarCustomTitle];
        }
      else
        {
          title = [NSString stringWithFormat:@"%@ \u2014 %@",
                            titleBarCustomTitle, title];
        }
      miniTitle = titleBarCustomTitle;
    }

  if (titleBarElementsMask & TitleBarFileName)
    {
      if ([title length] == 0)
        {
          title = [NSString stringWithFormat:@"%@", [self fileName]];
        }
      else
        {
          title = [title stringByAppendingFormat:@"\u2014 %@", [self fileName]];
        }
    }

  [win setTitle:title];
  [win setMiniwindowTitle:miniTitle];
}

- (void)windowWillClose:(NSNotification *)n
{
  NSLog(@"Window WILL close.");

  [tView closeProgram];

  [[NSApp delegate] closeWindow:self];
  
  [self autorelease];
}

- (BOOL)windowShouldClose:(id)sender
{
  NSLog(@"Window SHOULD close.");
  if ([[self window] isDocumentEdited])
    {
      if (NSRunAlertPanel(@"Close",
                          @"Closing this window will terminate"
                          @" running process(es) inside it.",
                          @"Cancel", @"Close anyway", nil)
          == NSAlertDefaultReturn)
        {
          return NO;
        }
    }

  return YES;
}

- (void)viewBecameIdle
{
  NSString *t;

  NSDebugLLog(@"idle",@"%@ _becameIdle",self);

  t = [[self window] title];
  t = [t stringByAppendingString:_(@" (idle)")];
  [[self window] setTitle:t];

  t = [[self window] miniwindowTitle];
  t = [t stringByAppendingString:_(@" (idle)")];
  [[self window] setMiniwindowTitle:t];
  
  [[NSApp delegate] window:self becameIdle:YES];
}

- (void)viewBecameNonIdle
{
  NSDebugLLog(@"idle",@"%@ _becameNonIdle",self);
  
  [[NSApp delegate] window:self becameIdle:NO];
}

- (void)preferencesDidChange:(NSNotification *)notif
{
  Defaults *prefs = [notif userInfo];
  id       value;
  int      intValue;
  BOOL     boolValue;
  BOOL     isWindowSizeChanged = NO;

  if (!livePreferences)
    {
      livePreferences = [preferences copy];
    }

  //--- For Window usage only ---
  if ((intValue = [prefs windowHeight]) && intValue != terminalRows)
    {
      terminalRows = intValue;
      isWindowSizeChanged = YES;
      [livePreferences setWindowHeight:intValue];
    }
  if ((intValue = [prefs windowWidth]) && intValue != terminalRows)
    {
      terminalColumns = intValue;
      isWindowSizeChanged = YES;
      [livePreferences setWindowWidth:intValue];
    }

  // Title Bar:
  if ((intValue = [prefs titleBarElementsMask]) &&
      intValue != titleBarElementsMask)
    {
      titleBarElementsMask = intValue;
      titleBarCustomTitle = [prefs customTitle];
      [self updateTitleBar:nil];
      [livePreferences setTitleBarElementsMask:titleBarElementsMask];
      [livePreferences setCustomTitle:titleBarCustomTitle];
    }
  
  if ((intValue = [prefs windowCloseBehavior]))
    {
      windowCloseBehavior = intValue;
      [livePreferences setWindowCloseBehavior:intValue];      
    }

  //--- For Window and View usage ---
  if ((boolValue = [prefs scrollBackEnabled]) && boolValue != scrollBackEnabled)
    {
      scrollBackEnabled = boolValue;
      if (scrollBackEnabled == YES)
        {
          [tView retain];
          [tView removeFromSuperview];
          [hBox release];
          hBox = [[GSHbox alloc] init];

          [hBox addView:scroller enablingXResizing:NO];
          [scroller release];
          [hBox addView:tView];
          [tView release];
        }
      else
        {
          [tView retain];
          [tView removeFromSuperview];
          [scroller retain];
          [scroller removeFromSuperview];
          [hBox release];
          hBox = [[GSHbox alloc] init];
          
          [hBox addView:tView];
          [tView release];
        }
      [win setContentView:hBox];
      isWindowSizeChanged = YES;
      [livePreferences setScrollBackEnabled:boolValue];
    }

  if ((intValue = [prefs scrollBackLines]))
    {
      if (scrollBackEnabled == YES)
        {
          [tView setScrollBufferMaxLength:intValue];
          [livePreferences setScrollBackLines:intValue];
        }
      else
        {
          [tView setScrollBufferMaxLength:0];
        }
    }
  
  //---  For TerminalView usage only ---
  if ((value = [prefs terminalFont]))
    {
      [tView setFont:[value screenFont]];
      [tView setBoldFont:[Defaults boldTerminalFontForFont:value]];
      
      [livePreferences setTerminalFont:value];
      
      charCellSize = [Defaults characterCellSizeForFont:value];
      isWindowSizeChanged = YES;
      [tView setNeedsDisplay:YES];
    }

  // Display:
  if ((boolValue = [prefs scrollBottomOnInput]))
    {
      [tView setScrollBottomOnInput:boolValue];
      [livePreferences setScrollBottomOnInput:boolValue];
    }
  // Linux:
  if ((boolValue = [prefs useMultiCellGlyphs]))
    {
      [tView setUseMulticellGlyphs:boolValue];
      [preferences setUseMultiCellGlyphs:boolValue];
    }
  // Colors:
  if ((value = [prefs cursorColor]))
    {
      [tView setCursorStyle:[prefs cursorStyle]];
      [tView updateColors:prefs];
      [tView setNeedsDisplayInRect:[tView frame]];
      
      [preferences setCursorColor:value];
      [preferences setCursorStyle:[prefs cursorStyle]];
    }

  //---  For TerminalParser usage only ---
  // TODO: First, GNUstep preferences should have reasonable settings (see
  // comment in terminal parser about Command, Alternate and Control modifiers).
  // The best way is to create Preferences' Keyboard panel.
  // if ((value = [prefs objectForKey:CharacterSetKey]))
  // if ((value = [prefs objectForKey:CommandAsMetaKey]))
  // if ((value = [prefs objectForKey:DoubleEscapeKey]))
  if (isWindowSizeChanged)
    {
      [self calculateSizes];
      [win setContentSize:winContentSize];
    }
}

// --- Actions ---
- (void)changeFont:(id)sender
{
  NSLog(@"TerminalWindow: changeFont:%@", [sender className]);
  if ([sender isKindOfClass:[NSFontManager class]]) // Font Panel
    {
    }
  else if ([sender isKindOfClass:[NSFont class]])   // Preferences
    {
    }
}

@end
