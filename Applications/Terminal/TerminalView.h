/*
  Copyright 
  2002 Alexander Malmberg <alexander@malmberg.org>
  2015-2017 Sergii Stoian <stoyan255@gmail.com>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#ifndef TerminalView_h
#define TerminalView_h

#import <Foundation/NSFileHandle.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSView.h>
#import <AppKit/NSMenu.h>

#import "Terminal.h"
#import "TerminalParser_Linux.h"

extern NSString
	*TerminalViewBecameIdleNotification,
	*TerminalViewBecameNonIdleNotification,
	*TerminalViewTitleDidChangeNotification;

struct selection_range
{
  int location,length;
};

@interface TerminalView : NSView
{
  NSString	*title_window;
  NSString	*title_miniwindow;
  
  NSString	*programPath;
  NSString	*childTerminalName;
  int		childPID;

  int		master_fd;
  NSFileHandle	*masterFDHandle;
  
  NSObject<TerminalParser> *tp;

  NSFont	*font;
  NSFont	*boldFont;
  int		font_encoding;
  int		boldFont_encoding;
  BOOL		use_multi_cell_glyphs;
  float		fx,fy,fx0,fy0;

  BOOL		blackOnWhite;

  struct {
    int x0,y0,x1,y1;
  } dirty;

  NSScroller	*scroller;
  BOOL		scroll_bottom_on_input;

  unsigned char	*write_buf;
  int		write_buf_len, write_buf_size;

  int		max_scrollback;
  int		sb_length;
  int		current_scroll;
  screen_char_t	*sbuf;

  int		sx,sy;
  screen_char_t *screen;

  int cursor_x, cursor_y;
  int current_x,current_y;

  int  draw_all; /* 0=only lazy, 1=don't know, do all, 2=do all */
  BOOL draw_cursor;

  struct selection_range selection;

  /* scrolling by compositing takes a long while, so we break out of such
     loops fairly often to process other events */
  int num_scrolls;

  /* To avoid doing lots of scrolling compositing, we combine multiple
     full-screen scrolls. pending_scroll is the combined pending line delta */
  int pending_scroll;

  BOOL ignore_resize;

  float border_x, border_y;

  id           defaults;

  // Colors
  NSColor	*cursorColor;
  NSUInteger	cursorStyle;
  // Window:Background
  CGFloat	WIN_BG_H;
  CGFloat	WIN_BG_S;
  CGFloat	WIN_BG_B;

  // Window:Selection
  CGFloat	WIN_SEL_H;
  CGFloat	WIN_SEL_S;
  CGFloat	WIN_SEL_B;

  // Text:Normal
  CGFloat	TEXT_NORM_H;
  CGFloat	TEXT_NORM_S;
  CGFloat	TEXT_NORM_B;

  // Text:Blink
  CGFloat	TEXT_BLINK_H;
  CGFloat	TEXT_BLINK_S;
  CGFloat	TEXT_BLINK_B;

  // Text:Bold
  CGFloat	TEXT_BOLD_H;
  CGFloat	TEXT_BOLD_S;
  CGFloat	TEXT_BOLD_B;

  // Text:Inverse
  CGFloat	INV_BG_H;
  CGFloat	INV_BG_S;
  CGFloat	INV_BG_B;
  CGFloat	INV_FG_H;
  CGFloat	INV_FG_S;
  CGFloat	INV_FG_B;
}

- initWithPrefences:(id)preferences;
- (id)preferences;

- (void)setIgnoreResize:(BOOL)ignore;

- (void)setBorder:(float)x :(float)y;

- (void)setFont:(NSFont *)aFont;
- (void)setBoldFont:(NSFont *)bFont;
- (int)scrollBufferLength;
- (void)setScrollBufferMaxLength:(int)lines;
- (void)setScrollBottomOnInput:(BOOL)scrollBottom;
- (void)setUseMulticellGlyphs:(BOOL)multicellGlyphs;
- (void)setCursorStyle:(NSUInteger)style;

- (NSString *)shellPath;
- (NSString *)deviceName;
- (NSString *)windowSize;
  
- (NSString *)windowTitle;
- (NSString *)miniwindowTitle;
- (BOOL)isUserProgramRunning;

+ (void)registerPasteboardTypes;

@end

@interface TerminalView (display) <TerminalScreen>
- (void)updateColors:(NSDictionary *)prefs;
- (void)setNeedsLazyDisplayInRect:(NSRect)r;
@end

/* TODO: this is ugly */
@interface TerminalView (scrolling_2)
- (void)setScroller:(NSScroller *)sc;
@end

@interface TerminalView (input_2)
- (void)readData;

- (void)closeProgram;

// Next 3 methods return PID of program
- (int)runProgram:(NSString *)path
    withArguments:(NSArray *)args
     initialInput:(NSString *)d;
- (int)runProgram:(NSString *)path
    withArguments:(NSArray *)args
      inDirectory:(NSString *)directory
     initialInput:(NSString *)d
             arg0:(NSString *)arg0;
- (int)runShell;
@end

#endif

