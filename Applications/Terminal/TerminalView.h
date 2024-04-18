/*
  Copyright (c) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#ifndef TerminalView_h
#define TerminalView_h

#include <stdint.h>

#import <Foundation/NSFileHandle.h>
#include "Foundation/NSObjCRuntime.h"
#import <AppKit/NSScroller.h>
#import <AppKit/NSView.h>
#import <AppKit/NSMenu.h>

#import "Terminal.h"
#import "TerminalParser_Linux.h"

#import "Defaults.h"

#define SCROLLBACK_DEFAULT 256
#define SCROLLBACK_MAX INT_MAX

extern NSString *TerminalViewBecameIdleNotification;
extern NSString *TerminalViewBecameNonIdleNotification;
extern NSString *TerminalViewTitleDidChangeNotification;
extern NSString *TerminalViewSizeDidChangeNotification;

struct selection_range {
  int location, length;
};

@interface TerminalView : NSView
{
  Defaults *defaults;
  NSString *xtermTitle;
  NSString *xtermIconTitle;

  NSString *programPath;
  NSString *childTerminalName;
  int child_pid;

  int master_fd;
  NSFileHandle *masterFDHandle;

  NSObject<TerminalParser> *terminalParser;

  NSFont *font;
  NSFont *boldFont;
  int font_encoding;
  int boldFont_encoding;
  BOOL useMultiCellGlyphs;
  float fx, fy, fx0, fy0;

  struct {
    int x0, y0, x1, y1;
  } dirty;

  unsigned char *write_buf;
  int write_buf_len;
  int write_buf_size;

  // ---
  // Scrolling
  // ---
  NSScroller *scroller;
  BOOL shouldScrollBottomOnInput; /* preference */

  // Scrollback
  screen_char_t *scrollback; /* scrollback buffer content storage */
  int curr_sb_position;      /* 0 = bottom; negative value = posision */
  int max_sb_depth;          /* maximum scrollback size in lines */
  int curr_sb_depth;         /* current scrollback size in lines */
  int alloc_sb_depth;        /* current number of lines which have allocated memory for */

  /* Scrolling by compositing takes a long while, so we break out of such
     loops fairly often to process other events */
  int num_scrolls;
  /* To avoid doing lots of scrolling compositing, we combine multiple
     full-screen scrolls. pending_scroll is the combined pending line delta */
  int pending_scroll;

  // ---
  // Screen - visible part of terminal contents
  // ---
  screen_char_t *screen;
  int screen_width;   // window width in characters (screen_char_t)
  int screen_height;  // window height in lines

  int cursor_x, cursor_y;
  int current_x, current_y;

  int draw_all; /* 0=only lazy, 1=don't know, do all, 2=do all */
  BOOL shouldDrawCursor;

  BOOL shouldIgnoreResize;
  BOOL shouldUpdateTitlebar;
  BOOL isActivityMonitorEnabled;

  float border_x, border_y;

  // Selection
  struct selection_range selection;
  NSString *additionalWordCharacters;

  // ------
  // Colors
  // ------
  NSColor *cursorColor;
  NSUInteger cursorStyle;
  // Window:Background
  CGFloat WIN_BG_H;
  CGFloat WIN_BG_S;
  CGFloat WIN_BG_B;

  // Window:Selection
  CGFloat WIN_SEL_H;
  CGFloat WIN_SEL_S;
  CGFloat WIN_SEL_B;

  // Text:Normal
  CGFloat TEXT_NORM_H;
  CGFloat TEXT_NORM_S;
  CGFloat TEXT_NORM_B;

  // Text:Blink
  CGFloat TEXT_BLINK_H;
  CGFloat TEXT_BLINK_S;
  CGFloat TEXT_BLINK_B;

  // Text:Bold
  CGFloat TEXT_BOLD_H;
  CGFloat TEXT_BOLD_S;
  CGFloat TEXT_BOLD_B;

  // Text:Inverse
  CGFloat INV_BG_H;
  CGFloat INV_BG_S;
  CGFloat INV_BG_B;
  CGFloat INV_FG_H;
  CGFloat INV_FG_S;
  CGFloat INV_FG_B;
}

- initWithPreferences:(id)preferences;
- (Defaults *)preferences;  // used by terminal parser
- (BOOL)resizeScrollbackBuffer:(BOOL)shouldGrow;

- (NSObject<TerminalParser> *)terminalParser;

- (NSRange)selectedRange;
- (void)setSelectedRange:(NSRange)range;
- (void)scrollRangeToVisible:(NSRange)range;
- (NSString *)stringRepresentation;

- (void)setIgnoreResize:(BOOL)ignore;
- (void)setBorderX:(float)x Y:(float)y;

- (void)setAdditionalWordCharacters:(NSString *)str;

- (void)setFont:(NSFont *)aFont;
- (void)setBoldFont:(NSFont *)bFont;
- (int)scrollBufferLength;
- (BOOL)setScrollBufferMaxLength:(int)lines;
- (void)setScrollBottomOnInput:(BOOL)scrollBottom;
- (void)setCursorStyle:(NSUInteger)style;

- (void)setCharset:(NSString *)charsetName;
- (void)setUseMulticellGlyphs:(BOOL)multicellGlyphs;
- (void)setDoubleEscape:(BOOL)doubleEscape;
- (void)setAlternateAsMeta:(BOOL)altAsMeta;

- (NSString *)xtermTitle;
- (NSString *)xtermIconTitle;
- (NSString *)programPath;
- (void)updateProgramPath;
- (NSString *)deviceName;
- (NSSize)windowSize;

- (BOOL)isUserProgramRunning;

+ (void)registerPasteboardTypes;

@end

@interface TerminalView (display) <TerminalScreen>

- (void)updateColors:(Defaults *)prefs;
- (void)setNeedsLazyDisplayInRect:(NSRect)r;

@end

@interface TerminalView (scrolling)
- (void)setScroller:(NSScroller *)sc;
@end

@interface TerminalView (Input_Output) <RunLoopEvents>

- (void)readData;
- (void)writeData;

- (void)closeProgram;

// Next 3 methods return PID of program
- (int)runProgram:(NSString *)path withArguments:(NSArray *)args initialInput:(NSString *)d;
- (int)runProgram:(NSString *)path
    withArguments:(NSArray *)args
      inDirectory:(NSString *)directory
     initialInput:(NSString *)d
             arg0:(NSString *)arg0;
- (int)runShell;

@end

#endif
