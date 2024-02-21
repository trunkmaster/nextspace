/*
  Copyright (c) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#ifndef Terminal_h
#define Terminal_h

#import "Foundation/NSString.h"

@class NSEvent;

typedef struct {
  unichar ch;
  unsigned char color;
  unsigned char attr;
  /*
    bits
    0,1   00000011 - 0x0-2 - intensity (0:half-bright 1:normal 2:bold)
    2     00000100 - 0x4   - underline
    3     00001000 - 0x8   - inverse
    4     00010000 - 0x10  - blink
    5     00100000 - 0x20  - unused
    6     01000000 - 0x40  - used as a selected flag internally
    7     10000000 - 0x80  - used as a dirty flag internally
  */
} screen_char_t;

/* Used as a marker. */
#define MULTI_CELL_GLYPH 0xfffe

@protocol TerminalScreen

- (void)ts_sendCString:(const char *)str;
- (void)ts_sendCString:(const char *)msg length:(int)len;

- (void)ts_gotoX:(int)x Y:(int)y;
- (void)ts_putChar:(screen_char_t)ch count:(int)c atX:(int)x Y:(int)y;
- (void)ts_putChar:(screen_char_t)ch count:(int)c offset:(int)ofs;

/* The portions scrolled/shifted from remain unchanged. However, it's
assumed that they will be cleared or overwritten before the redraw is
complete. (TODO check this) */
- (void)ts_scrollUpTop:(int)top bottom:(int)bottom rows:(int)nr save:(BOOL)save;
- (void)ts_scrollDownTop:(int)top bottom:(int)bottom rows:(int)nr;
- (void)ts_shiftRow:(int)y at:(int)x0 delta:(int)d;

- (screen_char_t)ts_getCharAtX:(int)x Y:(int)y;

- (void)ts_setTitle:(NSString *)new_title type:(int)title_type;

- (id)preferences;
- (BOOL)useMultiCellGlyphs;
- (int)relativeWidthOfCharacter:(unichar)ch;

@end

@protocol TerminalParser

- initWithTerminalScreen:(id<TerminalScreen>)ats width:(int)w height:(int)h;
- (void)processByte:(unsigned char)c;
- (void)setTerminalScreenWidth:(int)w height:(int)h cursorY:(int)cursor_y;
- (void)handleKeyEvent:(NSEvent *)e;
- (void)sendString:(NSString *)str;

- (void)setCharset:(NSString *)charsetName;
- (void)setDoubleEscape:(BOOL)doubleEscape;
- (void)setAlternateAsMeta:(BOOL)altAsMeta;

@end

#endif
