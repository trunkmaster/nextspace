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
#include <stdint.h>

@class NSEvent;

typedef struct {
  uint32_t ch;
  uint32_t grapheme; // opaque TerminalView text handle; zero means one scalar
  unsigned char color;
  unsigned char attr;
  // Ghostty colors: explicit RGB or terminal default; zero means legacy cell.
  uint32_t foregroundColor;
  uint32_t backgroundColor;
  /*
    bits
    0,1   00000011 - 0x0-2 - intensity (0:half-bright 1:normal 2:bold)
    2     00000100 - 0x4   - underline
    3     00001000 - 0x8   - inverse
    4     00010000 - 0x10  - blink
    5     00100000 - 0x20  - invisible
    6     01000000 - 0x40  - used as a selected flag internally
    7     10000000 - 0x80  - used as a dirty flag internally
  */
} screen_char_t;

// A tagged color keeps explicit black/white distinct from terminal defaults.
#define TERMINAL_COLOR_DEFAULT UINT32_C(0x01000000)
#define TERMINAL_COLOR_RGB UINT32_C(0x02000000)
static inline uint32_t TerminalRGB(unsigned r, unsigned g, unsigned b)
{
  return TERMINAL_COLOR_RGB | (r << 16) | (g << 8) | b;
}
static inline int TerminalCellUsesFullColors(screen_char_t cell)
{
  return cell.foregroundColor != 0;
}
static inline int TerminalCellAppearanceEqual(screen_char_t a, screen_char_t b)
{
  return a.ch == b.ch && a.grapheme == b.grapheme && a.color == b.color &&
      a.foregroundColor == b.foregroundColor && a.backgroundColor == b.backgroundColor &&
      (a.attr & 0x3f) == (b.attr & 0x3f);
}

/* Used as a marker. */
#define MULTI_CELL_GLYPH UINT32_MAX

static inline NSString *TerminalStringForScalar(uint32_t scalar)
{
  unichar units[2];
  if (scalar > 0x10ffff || (scalar >= 0xd800 && scalar <= 0xdfff)) scalar = 0xfffd;
  if (scalar <= 0xffff) { units[0] = scalar; return [NSString stringWithCharacters:units length:1]; }
  scalar -= 0x10000;
  units[0] = 0xd800 + (scalar >> 10); units[1] = 0xdc00 + (scalar & 0x3ff);
  return [NSString stringWithCharacters:units length:2];
}

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
@optional
- (void)ts_setCursorVisible:(BOOL)visible;
- (uint32_t)ts_internGrapheme:(NSString *)text;

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

@optional
// Batch PTY input so stateful backends snapshot once per read, not per byte.
- (void)processData:(const unsigned char *)bytes length:(NSUInteger)length;


@end

#endif
