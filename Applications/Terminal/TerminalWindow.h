/*
  Copyright (c) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#ifndef TerminalWindow_h
#define TerminalWindow_h

@class TerminalView;

#include <AppKit/NSWindowController.h>
#include <AppKit/NSScroller.h>
#include <GNUstepGUI/GSHbox.h>

#import "Defaults.h"
#import "TerminalIcon.h"

extern NSString *TerminalWindowNoMoreActiveWindowsNotification;
extern NSString *TerminalWindowSizeDidChangeNotification;

@interface TerminalWindowController : NSWindowController
{
  NSWindow *win;
  GSHbox *hBox;
  NSScroller *scroller;
  TerminalView *tView;

  Defaults *preferences;
  Defaults *livePreferences;
  NSString *fileName;

  // Window
  int terminalColumns;
  int terminalRows;
  WindowCloseBehavior windowCloseBehavior;

  // Title Bar
  NSUInteger titleBarElementsMask;
  NSString *titleBarCustomTitle;

  // Miniwindow
  TerminalIcon *miniIconView;
  NSTimer *animationTimer;

  // Display
  BOOL scrollBackEnabled;
  // BOOL scrollBackUnlimited;
  // int  scrollBackLines;
  // BOOL scrollBottomOnInput;

  int scrollerWidth;
  NSSize charCellSize;
  NSSize winContentSize;
  NSSize winMinimumSize;
}

// - initWithStartupFile:(NSString *)filePath;
- initWithPreferences:(NSDictionary *)defs startupFile:(NSString *)path;

- (TerminalView *)terminalView;
- (WindowCloseBehavior)closeBehavior;
// Returns preferences loaded and stored in file.
- (Defaults *)preferences;
// Returns preferences active for window. These type of preferences
// created when some options changed via "Info | Preferences" panel.
// If preferences were not changed during the life of the window this
// method returns preferences stored in file (defaults or session).
- (Defaults *)livePreferences;
- (Defaults *)livePreferencesCreateIfNotExist:(BOOL)create;
// Title Bar elements
- (NSString *)shellPath;
- (NSString *)deviceName;
- (NSString *)fileName;
- (NSString *)windowSizeString;

- (void)updateTitleBar:(NSNotification *)aNotification;
- (void)updateWindowSize:(NSSize)size;
- (void)setFont:(NSFont *)newFont updateWindowSize:(BOOL)resizeWindow;

@end

#endif
