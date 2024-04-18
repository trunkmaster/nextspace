/*
  Copyright (c) 2002, 2003 Alexander Malmberg <alexander@malmberg.org>
  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

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

#include <X11/Xutil.h>
#import <GNUstepGUI/GSDisplayServer.h>

#import "Controller.h"
#import "Defaults.h"
#import "TerminalWindow.h"
#import "TerminalView.h"

NSString *TerminalWindowNoMoreActiveWindowsNotification =
    @"TerminalWindowNoMoreActiveWindowsNotification";
NSString *TerminalWindowSizeDidChangeNotification = @"TerminalWindowSizeDidChangeNotification";

@implementation TerminalWindowController

#define CONTENT_H_BORDER 4
#define CONTENT_V_BORDER 2

// It's a hack to correctly represent window size in WM on resizing.
// There's no NSWindow methods to set base_width and base_height hints.
//
// XSizeHints documentation says "base_width and base_height members define the desired size of the
// window.". But WM use them to substract from window size to calculate windows size in resize
// increments count.
- (void)_baseSizeHack
{
  GSDisplayServer *xServer = GSCurrentServer();
  Display *xDisplay = [xServer serverDevice];
  Window _win = (Window)[xServer windowDevice:[win windowNumber]];
  XSizeHints size_hints;
  long supplied_return;

  XGetWMNormalHints(xDisplay, _win, &size_hints, &supplied_return);
  size_hints.flags |= PBaseSize;
  size_hints.base_width = scrollerWidth + 1 + CONTENT_H_BORDER;
  XSetWMNormalHints(xDisplay, _win, &size_hints);
}

- (void)calculateSizes
{
  // Scroller
  scrollerWidth = (scrollBackEnabled == YES) ? [NSScroller scrollerWidth] : 0;

  // calc the rects for our window
  winContentSize = NSMakeSize(charCellSize.width * terminalColumns + scrollerWidth + 1,
                              charCellSize.height * terminalRows + 1);
  winMinimumSize = NSMakeSize(charCellSize.width * MIN_COLUMNS + scrollerWidth + 1,
                              charCellSize.height * MIN_LINES + 1);
  // add the borders to the size
  winContentSize.width += CONTENT_H_BORDER;
  winContentSize.height += CONTENT_V_BORDER;
  winMinimumSize.width += CONTENT_H_BORDER;
  winMinimumSize.height += CONTENT_V_BORDER;
}

- (id)_setupWindow
{
  NSRect contentRect, windowRect;
  NSUInteger styleMask;

  // Make cache of preferences
  scrollBackEnabled = [preferences scrollBackEnabled];
  terminalRows = [preferences windowHeight];
  terminalColumns = [preferences windowWidth];
  titleBarElementsMask = [preferences titleBarElementsMask];
  titleBarCustomTitle = [preferences customTitle];

  // Sizes
  charCellSize = [Defaults characterCellSizeForFont:[preferences terminalFont]];
  [self calculateSizes];

  // NSLog(@"TerminalWindow: create window: %ix%i char cell:%@ window content:%@",
  //       terminalColumns, terminalRows,
  //       NSStringFromSize(charCellSize),
  //       NSStringFromSize(winContentSize));

  windowCloseBehavior = [preferences windowCloseBehavior];

  contentRect = NSMakeRect(0, 0, winContentSize.width, winContentSize.height);
  styleMask = (NSClosableWindowMask | NSTitledWindowMask | NSResizableWindowMask |
               NSMiniaturizableWindowMask);
  win = [[NSWindow alloc] initWithContentRect:contentRect
                                    styleMask:styleMask
                                      backing:NSBackingStoreRetained
                                        defer:YES];

  if (!(self = [super initWithWindow:win]))
    return nil;

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
  scroller =
      [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, scrollerWidth, charCellSize.height)];
  [scroller setArrowsPosition:NSScrollerArrowsMaxEnd];
  [scroller setEnabled:YES];
  [scroller setAutoresizingMask:NSViewHeightSizable];
  if (scrollBackEnabled) {
    [hBox addView:scroller enablingXResizing:NO];
    [scroller release];
  }

  // View
  tView = [[TerminalView alloc] initWithPreferences:preferences];
  [tView setIgnoreResize:YES];
  [tView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
  [tView setScroller:scroller];
  [hBox addView:tView];
  [tView release];
  [tView setIgnoreResize:NO];
  [win makeFirstResponder:tView];

  [tView setBorderX:4 Y:2];

  [win setContentView:hBox];
  DESTROY(hBox);

  [win release];

  return self;
}

- init
{
  [self initWithPreferences:nil startupFile:nil];

  return self;
}

- initWithPreferences:(NSDictionary *)defs startupFile:(NSString *)path
{
  self = [super init];

  if (defs == nil) {
    preferences = [[Defaults alloc] init];
  } else {
    preferences = [[Defaults alloc] initWithDefaults:defs];
  }
  [self _setupWindow];
  [[self window] setRepresentedFilename:path];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(preferencesDidChange:)
                                               name:TerminalPreferencesDidChangeNotification
                                             object:win];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(viewBecameIdle:)
                                               name:TerminalViewBecameIdleNotification
                                             object:tView];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(viewBecameNonIdle:)
                                               name:TerminalViewBecameNonIdleNotification
                                             object:tView];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(viewSizeDidChange:)
                                               name:TerminalViewSizeDidChangeNotification
                                             object:tView];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(updateTitleBar:)
                                               name:TerminalViewTitleDidChangeNotification
                                             object:tView];

  return self;
}

- (void)dealloc
{
  // NSLog(@"Window DEALLOC.");

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

// Title Bar elements
- (NSString *)shellPath
{
  return [tView programPath];
}

- (NSString *)deviceName
{
  return [tView deviceName];
}

// File name without extension
- (NSString *)fileName
{
  return [[[[self window] representedFilename] lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)windowSizeString
{
  NSSize size = [tView windowSize];

  return [NSString stringWithFormat:@"%.0fx%.0f", size.width, size.height];
}

// --- Notifications ---
- (void)viewSizeDidChange:(NSNotification *)aNotification
{
  [self updateWindowSize:[[aNotification object] windowSize]];
}

- (void)updateTitleBar:(NSNotification *)aNotification
{
  NSString *title;
  NSString *shellPath = [self shellPath];
  NSString *terminalWindowTitle = [tView xtermTitle];
  NSString *file;
  BOOL isActivityMonitorEnabled = [preferences isActivityMonitorEnabled];

  // NSLog(@"updateTitleBar");

  title = [NSString new];

  if (aNotification) {
    titleBarElementsMask = [preferences titleBarElementsMask];
  }
  if (titleBarElementsMask & TitleBarShellPath) {
    title = [title stringByAppendingFormat:@"%@ ", shellPath];
  }
  if (titleBarElementsMask & TitleBarDeviceName) {
    title = [title stringByAppendingFormat:@"(%@) ", [self deviceName]];
  }
  if (titleBarElementsMask & TitleBarWindowSize) {
    title = [title stringByAppendingFormat:@"%@ ", [self windowSizeString]];
  }

  if (titleBarElementsMask & TitleBarCustomTitle) {
    if ([title length] == 0) {
      title = [NSString stringWithFormat:@"%@ ", titleBarCustomTitle];
    } else {
      title = [NSString stringWithFormat:@"%@ \u2014 %@", titleBarCustomTitle, title];
    }
  }

  if ((titleBarElementsMask & TitleBarFileName) && (file = [self fileName]) != nil) {
    if ([title length] == 0) {
      title = [NSString stringWithFormat:@"%@", file];
    } else {
      title = [title stringByAppendingFormat:@"\u2014 %@", file];
    }
  }
  if ((titleBarElementsMask & TitleBarXTermTitle) && [terminalWindowTitle length]) {
    if ([title length] == 0) {
      title = [NSString stringWithFormat:@"%@", terminalWindowTitle];
    } else {
      title = [title stringByAppendingFormat:@"\u2014 %@", terminalWindowTitle];
    }
  }

  [win setTitle:title];

  if (isActivityMonitorEnabled != NO) {
    [win setDocumentEdited:[tView isUserProgramRunning]];
  }

  if (isActivityMonitorEnabled && ([win isMiniaturized] != NO)) {
    if (miniIconView == nil) {
      NSString *scrImagePath = [[NSBundle mainBundle] pathForResource:@"ScrollingOutput"
                                                               ofType:@"tiff"];

      miniIconView = [[TerminalIcon alloc] initWithFrame:NSMakeRect(0, 0, 64, 64)
                                          scrollingFrame:NSMakeRect(13, 17, 27, 23)];
      [miniIconView setImageScaling:NSScaleNone];
      miniIconView.iconImage = [NSApp applicationIconImage];
      miniIconView.scrollingImage = [[NSImage alloc] initWithContentsOfFile:scrImagePath];
      miniIconView.isMiniWindow = YES;
      [[win counterpart] setContentView:miniIconView];

      [miniIconView release];
    }

    [miniIconView setTitle:shellPath];

    if ( ([tView isUserProgramRunning] != NO)) {
      miniIconView.isAnimates = YES;
      [miniIconView animate];
    } else {
      miniIconView.isAnimates = NO;
      [miniIconView setNeedsDisplay:YES];
      [miniIconView display];
    }

  } else if (miniIconView) {
    [miniIconView setTitle:shellPath];
  } else {
    [win setMiniwindowTitle:shellPath];
  }
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  // NSLog(@"Window WILL close.");

  [tView closeProgram];

  [[NSApp delegate] closeTerminalWindow:self];

  [self autorelease];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
  [self _baseSizeHack];
}

- (BOOL)windowShouldClose:(id)sender
{
  // NSLog(@"Window SHOULD close.");
  if ([[self window] isDocumentEdited]) {
    if (NSRunAlertPanel(@"Close",
                        @"Closing this window will terminate"
                        @" running process(es) inside it.",
                        @"Cancel", @"Close anyway", nil) == NSAlertDefaultReturn) {
      return NO;
    }
  }

  return YES;
}

- (void)viewBecameIdle:(NSNotification *)aNotification
{
  NSString *t;

  NSDebugLLog(@"idle", @"%@ _becameIdle", self);

  t = [[self window] title];
  t = [t stringByAppendingString:_(@" (idle)")];
  [[self window] setTitle:t];

  t = [[self window] miniwindowTitle];
  t = [t stringByAppendingString:_(@" (idle)")];
  [[self window] setMiniwindowTitle:t];

  [[NSApp delegate] terminalWindow:self becameIdle:YES];
}

- (void)viewBecameNonIdle:(NSNotification *)aNotification
{
  NSDebugLLog(@"idle", @"%@ _becameNonIdle", self);

  [[NSApp delegate] terminalWindow:self becameIdle:NO];
}

// --- Preferences ---
- (Defaults *)preferences
{
  return preferences;
}

- (Defaults *)livePreferences
{
  return livePreferences;
}

- (Defaults *)livePreferencesCreateIfNotExist:(BOOL)create
{
  if (!livePreferences && create == YES) {
    livePreferences = [preferences copy];
  }

  return livePreferences;
}

// Use explicit (by keys) reading of changed preferences to check some
// setting was passed to us. Using Defaults methods always returns some values.
- (void)preferencesDidChange:(NSNotification *)notif
{
  Defaults *prefs = [[notif userInfo] objectForKey:@"Preferences"];
  int intValue;
  BOOL boolValue;
  BOOL isWindowSizeChanged = NO;
  // NSFont   *font = nil;

  [self livePreferencesCreateIfNotExist:YES];

  //--- For Window usage only ---
  if ((intValue = [prefs integerForKey:WindowHeightKey]) > 0 && (intValue != terminalRows)) {
    terminalRows = intValue;
    isWindowSizeChanged = YES;
    [livePreferences setWindowHeight:intValue];
  }
  if ((intValue = [prefs integerForKey:WindowWidthKey]) > 0 && (intValue != terminalColumns)) {
    intValue = [prefs windowWidth];
    terminalColumns = intValue;
    isWindowSizeChanged = YES;
    [livePreferences setWindowWidth:intValue];
  }

  // Title Bar:
  if ([prefs objectForKey:TitleBarElementsMaskKey]) {
    intValue = [prefs titleBarElementsMask];
    if (intValue != titleBarElementsMask) {
      titleBarElementsMask = intValue;
      [livePreferences setTitleBarElementsMask:intValue];
    }
    titleBarCustomTitle = [prefs customTitle];
    [livePreferences setCustomTitle:titleBarCustomTitle];
    [self updateTitleBar:nil];
  }

  if ([prefs objectForKey:WindowCloseBehaviorKey]) {
    windowCloseBehavior = [prefs integerForKey:WindowCloseBehaviorKey];
    [livePreferences setWindowCloseBehavior:windowCloseBehavior];
  }

  //--- For Window and View usage ---
  if ([prefs objectForKey:ScrollBackEnabledKey]) {
    boolValue = [prefs boolForKey:ScrollBackEnabledKey];
    if (boolValue != scrollBackEnabled) {
      scrollBackEnabled = boolValue;
      if (scrollBackEnabled == YES) {
        [tView retain];
        [tView removeFromSuperview];
        [hBox release];
        hBox = [[GSHbox alloc] init];

        [hBox addView:scroller enablingXResizing:NO];
        [scroller release];
        [hBox addView:tView];
        [tView release];
      } else {
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
  }

  if ([prefs objectForKey:ScrollBackUnlimitedKey] != nil) {
    [livePreferences setScrollBackUnlimited:[prefs boolForKey:ScrollBackUnlimitedKey]];
  }

  if ([prefs objectForKey:ScrollBackLinesKey] != nil) {
    intValue = [prefs scrollBackLines];  // contains sanity checks
    if (scrollBackEnabled == YES) {
      [tView setScrollBufferMaxLength:intValue];
      [livePreferences setScrollBackLines:intValue];
    } else {
      [tView setScrollBufferMaxLength:0];
    }
  }

  //---  For TerminalView usage only ---
  // Font changed
  if ([prefs objectForKey:TerminalFontKey]) {  // Should be a separate method: font can be changed
                                               // in defferent ways.
    [self setFont:[prefs terminalFont] updateWindowSize:NO];
    isWindowSizeChanged = YES;
  }
  // Bold font changed
  if ([prefs objectForKey:TerminalFontUseBoldKey]) {
    [livePreferences setUseBoldTerminalFont:[prefs useBoldTerminalFont]];
    [self setFont:nil updateWindowSize:NO];
  }

  // Display:
  if ([prefs objectForKey:ScrollBottomOnInputKey]) {
    boolValue = [prefs scrollBottomOnInput];
    [tView setScrollBottomOnInput:boolValue];
    [livePreferences setScrollBottomOnInput:boolValue];
  }

  // Shell:
  if ([prefs objectForKey:ShellKey]) {
    [livePreferences setShell:[prefs objectForKey:ShellKey]];
    [livePreferences setLoginShell:[prefs boolForKey:LoginShellKey]];
  }

  // Selection:
  if ([prefs objectForKey:WordCharactersKey]) {
    [tView setAdditionalWordCharacters:[prefs objectForKey:WordCharactersKey]];
    [livePreferences setWordCharacters:[prefs objectForKey:WordCharactersKey]];
  }

  // Linux:
  if ([prefs objectForKey:CharacterSetKey]) {
    NSString *cs = [prefs objectForKey:CharacterSetKey];
    [tView setCharset:cs];
    [livePreferences setCharacterSet:cs];
  }
  if ([prefs objectForKey:UseMultiCellGlyphsKey]) {
    boolValue = [prefs useMultiCellGlyphs];
    [tView setUseMulticellGlyphs:boolValue];
    [livePreferences setUseMultiCellGlyphs:boolValue];
  }
  if ([prefs objectForKey:DoubleEscapeKey]) {
    boolValue = [prefs doubleEscape];
    [tView setDoubleEscape:boolValue];
    [livePreferences setDoubleEscape:boolValue];
  }
  if ([prefs objectForKey:AlternateAsMetaKey]) {
    boolValue = [prefs alternateAsMeta];
    [tView setAlternateAsMeta:boolValue];
    [livePreferences setAlternateAsMeta:boolValue];
  }
  // Colors:
  if ([prefs objectForKey:CursorColorKey]) {
    [tView setCursorStyle:[prefs cursorStyle]];
    [tView updateColors:prefs];  // TODO
    [tView setNeedsDisplayInRect:[tView frame]];

    // Update live preferences
    [livePreferences setCursorColor:[prefs cursorColor]];
    [livePreferences setCursorStyle:[prefs cursorStyle]];
    [livePreferences setWindowBackgroundColor:[prefs windowBackgroundColor]];
    [livePreferences setWindowSelectionColor:[prefs windowSelectionColor]];
    [livePreferences setTextNormalColor:[prefs textNormalColor]];
    [livePreferences setTextBoldColor:[prefs textBoldColor]];
    [livePreferences setTextBlinklColor:[prefs textBlinkColor]];
    [livePreferences setTextInverseBackground:[prefs textInverseBackground]];
    [livePreferences setTextInverseForeground:[prefs textInverseForeground]];
    [livePreferences setUseBoldTerminalFont:[prefs useBoldTerminalFont]];
  }

  //---  For TerminalParser usage only ---
  // TODO: First, GNUstep preferences should have reasonable settings (see
  // comment in terminal parser about Command, Alternate and Control modifiers).
  // The best way is to create Preferences' Keyboard panel.
  // if ((value = [prefs objectForKey:CharacterSetKey]))
  // if ((value = [prefs objectForKey:CommandAsMetaKey]))
  // if ((value = [prefs objectForKey:DoubleEscapeKey]))
  if (isWindowSizeChanged) {
    [self calculateSizes];
    [win setContentSize:winContentSize];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:TerminalWindowSizeDidChangeNotification
                      object:self];
  }
}

// --- Actions ---
// Update preferences. Don't do actual window resizing.
- (void)updateWindowSize:(NSSize)size
{
  [self livePreferencesCreateIfNotExist:YES];

  if (size.width != [livePreferences windowWidth]) {
    [livePreferences setWindowWidth:size.width];
    terminalColumns = size.width;
  }
  if (size.height != [livePreferences windowHeight]) {
    [livePreferences setWindowHeight:size.height];
    terminalRows = size.height;
  }

  [self updateTitleBar:nil];

  [[NSNotificationCenter defaultCenter] postNotificationName:TerminalWindowSizeDidChangeNotification
                                                      object:self];
}

- (void)setFont:(NSFont *)newFont updateWindowSize:(BOOL)resizeWindow
{
  NSFont *font;
  Defaults *prefs = [self livePreferencesCreateIfNotExist:YES];

  // Font
  if (newFont != nil) {
    font = [newFont screenFont];

    [prefs setTerminalFont:font];

    charCellSize = [Defaults characterCellSizeForFont:font];
    [win setResizeIncrements:NSMakeSize(charCellSize.width, charCellSize.height)];
    [tView setFont:font];
  } else {
    font = [prefs terminalFont];
  }

  // Bold font
  if ([prefs useBoldTerminalFont] == YES)
    [tView setBoldFont:[Defaults boldTerminalFontForFont:font]];
  else
    [tView setBoldFont:font];

  [tView setNeedsDisplay:YES];

  // Window
  if (resizeWindow) {
    // TODO: it must be one place to update window size
    // (TerminalView or TerminalWindow not both)
    [self updateWindowSize:[tView windowSize]];
    [self calculateSizes];
    [win setContentSize:winContentSize];
  }

  // [[NSNotificationCenter defaultCenter]
  //       	postNotificationName:TerminalWindowSizeDidChangeNotification
  //                             object:self];
}

// NSFontPanel delegate method.
// Called when clicked "Set" button in font panel or menu items under Font
// submenu.
- (void)changeFont:(id)sender
{
  NSFont *font;

  if ([sender isKindOfClass:[NSFontManager class]])  // Font Panel
  {
    font = [livePreferences terminalFont];
    if (font == nil)
      font = [preferences terminalFont];

    // NSLog(@"Selected font: %@ converted: %@", [sender selectedFont],
    //       [sender convertFont:[preferences terminalFont]]);

    [self setFont:[sender convertFont:font] updateWindowSize:YES];
  } else {
    // NSLog(@"TerminalWindow: changeFont called by %@", [sender className]);
  }
}

@end
