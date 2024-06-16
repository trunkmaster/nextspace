/*
  Copyright 2002, 2003 Alexander Malmberg <alexander@malmberg.org>
  Copyright 2005 forkpty replacement, Riccardo Mottola <rmottola@users.sf.net>
  Copyright 2015-2021 Sergii Stoian <stoyan255@gmail.com>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

/*
  TODO: Move pty and child process handling to another class. Make this a
  stupid but fast character cell display view.
*/

#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <termio.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>
#include <pty.h>
#include <sys/wait.h>

#import <AppKit/AppKit.h>
#import <GNUstepBase/Unicode.h>
#import <SystemKit/OSEFileSystemMonitor.h>

#import "TerminalWindow.h"
#import "TerminalView.h"

#pragma mark - Definitions

#define SCROLLBACK_CHANGE_STEP 1  // number of screens

@interface NSArray (IsEmpty)
- (BOOL)isEmpty;
@end
@implementation NSArray (IsEmpty)
- (BOOL)isEmpty
{
  BOOL isEmpty = NO;

  if (self.count > 0) {
    if (self.count == 1 && [self.firstObject isEqualToString:@""]) {
      isEmpty = YES;
    }
  } else {
    isEmpty = YES;
  }

  return isEmpty;
}
@end

/* TODO */
@interface NSView (unlockfocus)
- (void)unlockFocusNeedsFlush:(BOOL)flush;
@end

NSString *TerminalViewBecameIdleNotification = @"TerminalViewBecameIdle";
NSString *TerminalViewBecameNonIdleNotification = @"TerminalViewBecameNonIdle";
NSString *TerminalViewTitleDidChangeNotification = @"TerminalViewTitleDidChange";
NSString *TerminalViewSizeDidChangeNotification = @"TerminalViewSizeDidChange";

// @interface TerminalView (scrolling)
// - (void)_handlePendingScroll:(BOOL)lockFocus;
// - (void)_updateScroller;
// - (void)_scrollTo:(int)new_scroll update:(BOOL)update;
// - (void)setScroller:(NSScroller *)sc;
// @end

// @interface TerminalView (selection)
// - (void)_clearSelection;
// @end


#pragma mark - Scrolling

//------------------------------------------------------------------------------
//--- Scrolling
//------------------------------------------------------------------------------

@implementation TerminalView (scrolling)

/* handle accumulated pending scrolls with a single composite */
- (void)_handlePendingScroll:(BOOL)lockFocus
{
  float x0, y0, w, h, dx, dy;

  if (!pending_scroll) {
    return;
  }

  if ((pending_scroll >= screen_height) || (pending_scroll <= -screen_height)) {
    pending_scroll = 0;
    return;
  }

  NSDebugLLog(@"draw", @"_handlePendingScroll %i %i", pending_scroll, lockFocus);

  dx = x0 = 0;
  w = fx * screen_width;

  if (pending_scroll > 0) {
    y0 = 0;
    h = (screen_height - pending_scroll) * fy;
    dy = pending_scroll * fy;
    y0 = (screen_height * fy) - y0 - h;
    dy = (screen_height * fy) - dy - h;
  } else {
    pending_scroll = -pending_scroll;

    y0 = pending_scroll * fy;
    h = (screen_height - pending_scroll) * fy;
    dy = 0;
    y0 = screen_height * fy - y0 - h;
    dy = screen_height * fy - dy - h;
  }

  if (lockFocus) {
    [self lockFocus];
  }
  DPScomposite(GSCurrentContext(), border_x + x0, border_y + y0, w, h, [self gState], border_x + dx,
               border_y + dy, NSCompositeCopy);
  if (lockFocus) {
    [self unlockFocusNeedsFlush:NO];
  }

  num_scrolls++;
  pending_scroll = 0;
}

- (void)_updateScroller
{
  if (curr_sb_depth) {
    [scroller setEnabled:YES];
    [scroller setFloatValue:(curr_sb_position + curr_sb_depth) / (float)(curr_sb_depth)
             knobProportion:screen_height / (float)(screen_height + curr_sb_depth)];
  } else {
    [scroller setEnabled:NO];
  }
}

- (void)_scrollTo:(int)new_scroll update:(BOOL)update
{
  if (new_scroll > 0) {
    new_scroll = 0;
  }

  if (new_scroll < -curr_sb_depth) {
    new_scroll = -curr_sb_depth;
  }

  if (new_scroll == curr_sb_position) {
    return;
  }

  curr_sb_position = new_scroll;

  if (update)
    [self _updateScroller];

  [self setNeedsDisplay:YES];
}

- (void)scrollWheel:(NSEvent *)e
{
  float delta = [e deltaY];  // with multiplier applied in XGServerEvent.m
  float shift;
  int new_scroll;

  if ([e modifierFlags] & NSShiftKeyMask)
    shift = delta < 0 ? -1 : 1;  // one line
  else if ([e modifierFlags] & NSControlKeyMask)
    shift = delta < 0 ? -screen_height : screen_height;  // one page
  else
    shift = delta;  // as specified by backend

  new_scroll = curr_sb_position - shift;
  [self _scrollTo:new_scroll update:YES];
}

- (void)_updateScroll:(id)sender
{
  int new_scroll;
  int part = [scroller hitPart];
  BOOL update = YES;

  if (part == NSScrollerKnob || part == NSScrollerKnobSlot) {
    new_scroll = ([scroller floatValue] - 1.0) * curr_sb_depth;
    update = NO;
  } else if (part == NSScrollerDecrementLine) {
    new_scroll = curr_sb_position - 1;
  } else if (part == NSScrollerDecrementPage) {
    new_scroll = curr_sb_position - screen_height / 2;
  } else if (part == NSScrollerIncrementLine) {
    new_scroll = curr_sb_position + 1;
  } else if (part == NSScrollerIncrementPage) {
    new_scroll = curr_sb_position + screen_height / 2;
  } else {
    return;
  }

  [self _scrollTo:new_scroll update:update];
}

- (void)setScroller:(NSScroller *)sc
{
  [scroller setTarget:nil];
  ASSIGN(scroller, sc);
  [self _updateScroller];
  [scroller setTarget:self];
  [scroller setAction:@selector(_updateScroll:)];
}

@end


#pragma mark - Display

//------------------------------------------------------------------------------
//--- TerminalScreen protocol implementation and rendering methods
//------------------------------------------------------------------------------
@implementation TerminalView (display)

#define ADD_DIRTY(ax0, ay0, asx, asy) \
  do {                                \
    if (dirty.x0 == -1) {             \
      dirty.x0 = (ax0);               \
      dirty.y0 = (ay0);               \
      dirty.x1 = (ax0) + (asx);       \
      dirty.y1 = (ay0) + (asy);       \
    } else {                          \
      if (dirty.x0 > (ax0)) {         \
        dirty.x0 = (ax0);             \
      }                               \
      if (dirty.y0 > (ay0)) {         \
        dirty.y0 = (ay0);             \
      }                               \
      if (dirty.x1 < (ax0) + (asx)) { \
        dirty.x1 = (ax0) + (asx);     \
      }                               \
      if (dirty.y1 < (ay0) + (asy)) { \
        dirty.y1 = (ay0) + (asy);     \
      }                               \
    }                                 \
  } while (0)

#define SCREEN(x, y) (screen[(y) * screen_width + (x)])

static int total_draw = 0;


#pragma mark - Colors
//
// --- Colors
//
static const float color_h[8] = {0, 240, 120, 180, 0, 300, 30, 0};
static const float color_s[8] = {0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0};
static const float color_b[8] = {0.0, 1.0, 0.6, 0.6, 1.0, 1.0, 1.0, 0.7};
// color values:
// 	0 - black		"\e[30"
// 	1 - blue		"\e[34"
// 	2 - green		"\e[32"
// 	3 - cyan		"\e[36"
// 	4 - red			"\e[31"
// 	5 - magenta		"\e[35"
// 	6 - yellow		"\e[33"
// 	7 - lightgray		"\e[37"
// intensity values:
// 	0 - half-bright
// 	1 - normal
// 	2 - bold
static void set_background(NSGraphicsContext *gc, unsigned char color, unsigned char in,
                           BOOL lightBackground)
{
  float bh, bs, bb;  // hue, saturation, brightness
  int bg = color >> 4;

  // fprintf(stderr, "set_background: %i >>4 %i\n", color, bg);

  if (bg >= 8)
    bg -= 8;

  if (bg == 0)
    bb = lightBackground ? 1.0 : 0.0;
  else
    bb = 0.6;

  bs = color_s[bg];
  bh = color_h[bg] / 360.0;

  DPSsethsbcolor(gc, bh, bs, bb);
}

static void set_foreground(NSGraphicsContext *gc, unsigned char color, unsigned char intensity)
{
  int fg = color;
  float h, s, b = 1.0;

  // fprintf(stderr, "set_foreground: %i intensity: %i invert:%s \n",
  //         color, intensity, blackOnWhite ? "YES" : "NO");

  if (fg >= 8) {
    fg -= 8;
  }

  // Colors
  // Here 'blackOnWhite' was set to YES if:
  // - window background is light;
  // - FG == BG
  // - FG == 7, BG == 0
  // if (lightBackground) {
  //   if (fg == 0) // Black becomes white
  //     fg = 7;
  //   else if (fg == 7)  // White becomes black
  //     fg = 0;
  //   else  // Other colors are half-bright
  //     intensity = 0;
  // }

  // Hue
  h = color_h[fg] / 360.0;

  // Saturation
  s = color_s[fg];
  // if (intensity == 2)
  //   s *= 0.5;

  // Brightness
  if (intensity == 0)  // half-bright
    b = color_b[fg] * 0.5;
  else if (intensity == 1)  // normal
    b = color_b[fg] * 0.8;
  else if (intensity == 2)  // bold
    b = color_b[fg];

  if (fg == 0)  // black not matter what intensity is
    b = 0.0;
  else if (intensity == 2)  // bold
    b = color_b[fg];
  else if (intensity == 0)  // half-bright
    b *= color_b[fg] * 0.8;

  DPSsethsbcolor(gc, h, s, b);
}

- (void)updateColors:(Defaults *)prefs
{
  NSColor *winBG, *winSel, *winText, *winBlink, *winBold, *invBG, *invFG;

  if (!prefs)
    prefs = defaults;

  if (cursorColor) {
    [cursorColor release];
  }
  cursorColor = [[prefs cursorColor] retain];

  winBG = [prefs windowBackgroundColor];
  WIN_BG_H = [winBG hueComponent];
  WIN_BG_S = [winBG saturationComponent];
  WIN_BG_B = [winBG brightnessComponent];

  winSel = [prefs windowSelectionColor];
  WIN_SEL_H = [winSel hueComponent];
  WIN_SEL_S = [winSel saturationComponent];
  WIN_SEL_B = [winSel brightnessComponent];

  winText = [prefs textNormalColor];
  TEXT_NORM_H = [winText hueComponent];
  TEXT_NORM_S = [winText saturationComponent];
  TEXT_NORM_B = [winText brightnessComponent];

  winBlink = [prefs textBlinkColor];
  TEXT_BLINK_H = [winBlink hueComponent];
  TEXT_BLINK_S = [winBlink saturationComponent];
  TEXT_BLINK_B = [winBlink brightnessComponent];

  winBold = [prefs textBoldColor];
  TEXT_BOLD_H = [winBold hueComponent];
  TEXT_BOLD_S = [winBold saturationComponent];
  TEXT_BOLD_B = [winBold brightnessComponent];

  invBG = [prefs textInverseBackground];
  INV_BG_H = [invBG hueComponent];
  INV_BG_S = [invBG saturationComponent];
  INV_BG_B = [invBG brightnessComponent];

  invFG = [prefs textInverseForeground];
  INV_FG_H = [invFG hueComponent];
  INV_FG_S = [invFG saturationComponent];
  INV_FG_B = [invFG brightnessComponent];
}

#pragma mark - Rendering

// ---
// --- Rendering
// ---
- (void)drawRect:(NSRect)r
{
  int ix, iy;
  char buf[8];
  NSGraphicsContext *cur = GSCurrentContext();
  int x0, y0, x1, y1;
  NSFont *f, *current_font = nil;

  int encoding;

  NSDebugLLog(@"draw", @"drawRect: (%g %g)+(%g %g) %i\n", r.origin.x, r.origin.y, r.size.width,
              r.size.height, draw_all);

  if (pending_scroll) {
    [self _handlePendingScroll:NO];
  }

  // Window Background color set
  DPSsethsbcolor(cur, WIN_BG_H, WIN_BG_S, WIN_BG_B);

  /* draw the border around the view if needed */
  {
    float a, b;

    if (r.origin.x < border_x) {
      DPSrectfill(cur, r.origin.x, r.origin.y, border_x - r.origin.x, r.size.height);
    }
    if (r.origin.y < border_y) {
      DPSrectfill(cur, r.origin.x, r.origin.y, r.size.width, border_y - r.origin.y);
    }

    a = border_x + screen_width * fx;
    b = r.origin.x + r.size.width;
    if (b > a) {
      DPSrectfill(cur, a, r.origin.y, b - a, r.size.height);
    }
    a = border_y + screen_height * fy;
    b = r.origin.y + r.size.height;
    if (b > a) {
      DPSrectfill(cur, r.origin.x, a, r.size.width, b - a);
    }
  }

  /* draw vertical black line next after scrollbar */
  if ((alloc_sb_depth > 0) && (r.origin.x < border_x)) {
    DPSsetgray(cur, 0.0);
    DPSrectfill(cur, r.origin.x, r.origin.y, r.origin.x + 1, r.size.height);
  }

  /* figure out what character cells might need redrawing */
  r.origin.x -= border_x;
  r.origin.y -= border_y;

  x0 = floor(r.origin.x / fx);
  x1 = ceil((r.origin.x + r.size.width) / fx);
  if (x0 < 0)
    x0 = 0;
  if (x1 >= screen_width)
    x1 = screen_width;

  y1 = floor(r.origin.y / fy);
  y0 = ceil((r.origin.y + r.size.height) / fy);
  y0 = screen_height - y0;
  y1 = screen_height - y1;
  if (y0 < 0)
    y0 = 0;
  if (y1 >= screen_height)
    y1 = screen_height;

  NSDebugLLog(@"draw", @"dirty (%i %i)-(%i %i)\n", x0, y0, x1, y1);

  shouldDrawCursor = shouldDrawCursor || draw_all || (SCREEN(cursor_x, cursor_y).attr & 0x80) != 0;

  {
    int ry;
    screen_char_t *ch;
    float scr_y, scr_x, start_x;

    /* setting the color is slow, so we try to avoid it */
    unsigned char last_color, color, last_attr;

#define R(scr_x, scr_y, fx, fy) DPSrectfill(cur, scr_x, scr_y, fx, fy)

    /* Legend:
       last_color - last used color in loop
       last_attr  - last used attributes in loop
       color      - local temporary color varialble
       ch->color - 8-bit color value which holds: FG (4 lower) and BG (4 higher)
       ch->color >> 4   - returns BG color in range 0-15
       ch->color & 0xf0 - returns BG color in range 16-255
       ch->color & 0x0f - returns FG color in range 0-15
    */

    //------------------- BACKGROUND ------------------------------------------------
    last_color = -1;
    last_attr = 0;
    DPSsethsbcolor(cur, WIN_BG_H, WIN_BG_S, WIN_BG_B);
    /* Fill the background of dirty cells. Since the background doesn't
       change that often, runs of dirty cells with the same background color
       are combined and drawn with a single rectfill. */
    for (iy = y0; iy < y1; iy++) {
      ry = iy + curr_sb_position;
      if (ry >= 0) {
        ch = &SCREEN(x0, ry);
      } else {
        ch = &scrollback[x0 + (alloc_sb_depth + ry) * screen_width];
      }

      scr_y = (screen_height - 1 - iy) * fy + border_y;

      /* ~400 cycles/cell on average */
      start_x = -1;
      for (ix = x0; ix < x1; ix++, ch++) {
        /* no need to draw && not dirty */
        if (!draw_all && !(ch->attr & 0x80)) {
          if (start_x != -1) {
            scr_x = ix * fx + border_x;
            R(start_x, scr_y, scr_x - start_x, fy);
            start_x = -1;
          }
          continue;
        }

        scr_x = ix * fx + border_x;

        if (ch->attr & 0x8) {  //------------------------------------ BG INVERSE
          color = ch->color & 0x0f;
          if (ch->attr & 0x40) {
            color ^= 0xf0;
          }

          if (color != last_color || ch->attr != last_attr) {
            if (start_x != -1) {
              R(start_x, scr_y, scr_x - start_x, fy);
              start_x = scr_x;
            }

            last_color = color;
            last_attr = ch->attr;

            // fprintf(stderr,
            //         "'%c' BG INVERSE color: %i (%i)"
            //         " attrs: %i (in:%i sel:%i)"
            //         " FG: %i BG: %i\n",
            //         ch->ch, ch->color, l_color,
            //         ch->attr, l_attr & 0x03, l_attr & 0x40,
            //         (ch->color & 0x0f), (ch->color>>4));

            if (ch->attr & 0x40) {  // selection
              // fprintf(stderr, "'%c' \tBG INVERSE: setting WIN_SEL\n", ch->ch);
              DPSsethsbcolor(cur, WIN_SEL_H, WIN_SEL_S, WIN_SEL_B);
            } else if ((ch->color & 0x0f) == 15 &&  // default foreground
                       (ch->color >> 4) == 15) {    // default background
              // fprintf(stderr, "'%c' \tBG INVERSE: setting INV_BG\n", ch->ch);
              DPSsethsbcolor(cur, INV_BG_H, INV_BG_S, INV_BG_B);
            } else {  // example: 'top' command column header background
              set_foreground(cur, last_color, last_attr & 0x03);
            }
          }
        } else {  //---------------------------------------------------- BG NORMAL
          color = ch->color & 0xf0;
          if (ch->attr & 0x40) {
            color ^= 0xf0;  // selected
          }

          if (color != last_color || ch->attr != last_attr) {
            if (start_x != -1) {
              R(start_x, scr_y, scr_x - start_x, fy);
              start_x = scr_x;
            }

            last_color = color;
            last_attr = ch->attr;

            // fprintf(stderr,
            //         "'%c' BG NORMAL color: %i (%i) attrs: %i (in:%i sel:%i)"
            //         " FG: %i BG: %i\n",
            //         ch->ch, ch->color, l_color, ch->attr, l_attr & 0x03,(ch->attr & 0x40),
            //         (ch->color & 0x0f), (ch->color>>4));

            // Window was resized and added empty chars have no attributes.
            // Set FG and BG to default values
            if ((color == 0 && (ch->color >> 4) == 0) && ch->ch == 0) {
              ch->color = 255;  // default FG/BG
              last_color = color = ch->color & 0xf0;
            }

            if (ch->attr & 0x40) {  // selection BG
              // fprintf(stderr, "'%c' \tBG NORMAL: setting WIN_SEL\n", ch->ch);
              DPSsethsbcolor(cur, WIN_SEL_H, WIN_SEL_S, WIN_SEL_B);
            } else if ((ch->color >> 4) == 15) {  // default BG
              // fprintf(stderr, "'%c' \tBG NORMAL: setting WIN_BG\n", ch->ch);
              DPSsethsbcolor(cur, WIN_BG_H, WIN_BG_S, WIN_BG_B);
            } else {
              set_background(cur, last_color, last_attr & 0x03, NO);
            }
          }
        }

        if (start_x == -1) {
          start_x = scr_x;
        }
      }

      if (start_x != -1) {
        scr_x = ix * fx + border_x;
        R(start_x, scr_y, scr_x - start_x, fy);
      }
    }
    //------------------- CHARACTERS ------------------------------------------------
    last_color = -1;
    last_attr = 0;
    /* Now draw any dirty characters */
    for (iy = y0; iy < y1; iy++) {
      ry = iy + curr_sb_position;
      if (ry >= 0) {
        ch = &SCREEN(x0, ry);
      } else {
        ch = &scrollback[x0 + (alloc_sb_depth + ry) * screen_width];
      }

      scr_y = (screen_height - 1 - iy) * fy + border_y;

      for (ix = x0; ix < x1; ix++, ch++) {
        /* no need to draw && not dirty */
        if (!draw_all && !(ch->attr & 0x80)) {
          continue;
        }

        // Clear dirty bit
        ch->attr &= 0x7f;

        scr_x = ix * fx + border_x;

        //--- FOREGROUND
        /* ~1700 cycles/change */
        if ((ch->attr & 0x02) || (ch->ch != 0 && ch->ch != 32)) {
          if (ch->attr & 0x8) {  //-------------------------------- FG INVERSE
            color = ch->color & 0xf0;
            if (ch->attr & 0x40) {
              color ^= 0x0f;
            }

            if (color != last_color || ch->attr != last_attr) {
              last_color = color;
              last_attr = ch->attr;

              // fprintf(stderr,
              //         "'%c' FG INVERSE color: %i (%i) attrs: %i (in:%i sel:%i)"
              //         " FG: %i BG: %i\n",
              //         ch->ch, ch->color, l_color, ch->attr, l_attr & 0x03,l_attr & 0x40,
              //         (ch->color & 0x0f), (ch->color>>4));

              if (last_attr & 0x40) {  // selection FG
                // fprintf(stderr, "'%c' \tFG INVERSE: setting TEXT_NORM\n", ch->ch);
                DPSsethsbcolor(cur, TEXT_NORM_H, TEXT_NORM_S, TEXT_NORM_B);
              } else {
                // fprintf(stderr, "'%c' \tFG INVERSE: setting INV_FG\n", ch->ch);
                DPSsethsbcolor(cur, INV_FG_H, INV_FG_S, INV_FG_B);
              }
            }
          } else if (ch->attr & 0x10) {  //---------------------------- FG BLINK
            // fprintf(stderr, "'%c' blink\n", ch->ch);
            if (ch->attr != last_attr) {
              last_attr = ch->attr;
              if (last_attr & 0x40) {  // selection FG
                // fprintf(stderr, "'%c' \tFG INVERSE: setting TEXT_NORM\n", ch->ch);
                DPSsethsbcolor(cur, TEXT_NORM_H, TEXT_NORM_S, TEXT_NORM_B);
              } else {
                DPSsethsbcolor(cur, TEXT_BLINK_H, TEXT_BLINK_S, TEXT_BLINK_B);
              }
            }
          } else {  //------------------------------------------------ FG NORMAL
            color = ch->color & 0x0f;
            if (ch->attr & 0x40) {
              color ^= 0x0f;
            }

            if (color != last_color || ch->attr != last_attr) {
              last_color = color;
              last_attr = ch->attr;

              // fprintf(stderr,
              //         "'%c' FG NORMAL color: %i (%i)"
              //         " attrs: %i (in:%i sel:%i)"
              //         " FG: %i BG: %i\n",
              //         ch->ch, ch->color, l_color,
              //         ch->attr, l_attr & 0x03, l_attr & 0x40,
              //         (ch->color & 0x0f), (ch->color>>4));

              if (color == 15 || (ch->attr & 0x40)) {
                // fprintf(stderr,
                //         "'%c' \tFG NORMAL: setting TEXT_NORM\n",
                //         ch->ch);
                DPSsethsbcolor(cur, TEXT_NORM_H, TEXT_NORM_S, TEXT_NORM_B);
              } else {
                set_foreground(cur, last_color, last_attr & 0x03);
              }
            }
          }
        }

        //--- FONTS & ENCODING
        if (ch->ch != 0 && ch->ch != 32 && ch->ch != MULTI_CELL_GLYPH) {
          total_draw++;
          if ((ch->attr & 3) == 2) {
            encoding = boldFont_encoding;
            f = boldFont;
            if ((ch->color & 0x0f) == 15) {
              DPSsethsbcolor(cur, TEXT_BOLD_H, TEXT_BOLD_S, TEXT_BOLD_B);
            }
          } else {
            encoding = font_encoding;
            f = font;
          }
          if (f != current_font) {
            /* ~190 cycles/change */
            [f set];
            current_font = f;
          }

          /* we short-circuit utf8 for performance with back-art */
          /* TODO: short-circuit latin1 too? */
          if (encoding == NSUTF8StringEncoding) {
            unichar uch = ch->ch;
            if (uch >= 0x800) {
              buf[2] = (uch & 0x3f) | 0x80;
              uch >>= 6;
              buf[1] = (uch & 0x3f) | 0x80;
              uch >>= 6;
              buf[0] = (uch & 0x0f) | 0xe0;
              buf[3] = 0;
            } else if (uch >= 0x80) {
              buf[1] = (uch & 0x3f) | 0x80;
              uch >>= 6;
              buf[0] = (uch & 0x1f) | 0xc0;
              buf[2] = 0;
            } else {
              buf[0] = uch;
              buf[1] = 0;
            }
          } else {
            unichar uch = ch->ch;
            if (uch <= 0x80) {
              buf[0] = uch;
              buf[1] = 0;
            } else {
              unsigned char *pbuf = (unsigned char *)buf;
              unsigned int dlen = sizeof(buf) - 1;
              GSFromUnicode(&pbuf, &dlen, &uch, 1, encoding, NULL, GSUniTerminate);
            }
          }
          /* ~580 cycles */
          DPSmoveto(cur, scr_x + fx0, scr_y + fy0);
          /* baseline here for mc-case 0.65 */
          /* ~3800 cycles */
          DPSshow(cur, buf);

          /* ~95 cycles to ARTGState -DPSshow:... */
          /* ~343 cycles to isEmpty */
          /* ~593 cycles to currentpoint */
          /* ~688 cycles to transform */
          /* ~1152 cycles to FTFont -drawString:... */
          /* ~1375 cycles to -drawString:... setup */
          /* ~1968 cycles cmap lookup */
          /* ~2718 cycles sbit lookup */
          /* ~~2750 cycles blit setup */
          /* ~3140 cycles blit loop, empty call */
          /* ~3140 cycles blit loop, setup */
          /* ~3325 cycles blit loop, no write */
          /* ~3800 cycles total */
        }

        //--- UNDERLINE
        if (ch->attr & 0x4) {
          DPSrectfill(cur, scr_x, scr_y, fx, 1);
        }
      }
    }
  }

  //------------------- CURSOR ----------------------------------------------------
  if (shouldDrawCursor) {
    float x, y;
    [cursorColor set];

    x = cursor_x * fx + border_x;
    y = (screen_height - 1 - cursor_y + curr_sb_position) * fy + border_y;

    switch (cursorStyle) {
      case CURSOR_BLOCK_INVERT:  // 0
        DPScompositerect(cur, x, y, fx, fy, NSCompositeSourceIn);
        break;
      case CURSOR_BLOCK_STROKE:  // 1
        DPSrectstroke(cur, x + 0.5, y + 0.5, fx - 1.0, fy - 1.0);
        break;
      case CURSOR_BLOCK_FILL:  // 2
        DPSrectfill(cur, x, y, fx, fy);
        break;
      case CURSOR_LINE:  // 3
        DPSrectfill(cur, x, y, fx, fy * 0.1);
        break;
    }
    shouldDrawCursor = NO;
  }

  NSDebugLLog(@"draw", @"total_draw=%i", total_draw);

  draw_all = 1;
}

- (BOOL)isOpaque
{
  return YES;
}

- (void)setNeedsDisplayInRect:(NSRect)r
{
  draw_all = 2;
  [super setNeedsDisplayInRect:r];
}

- (void)setNeedsLazyDisplayInRect:(NSRect)r
{
  if (draw_all == 1) {
    draw_all = 0;
  }
  [super setNeedsDisplayInRect:r];
}


#pragma mark - Text manipulation

// ---
// --- Text manipulation
// ---
- (screen_char_t)ts_getCharAtX:(int)x Y:(int)y
{
  NSDebugLLog(@"ts", @"getCharAt: %i:%i", x, y);
  return SCREEN(x, y);
}

- (void)ts_putChar:(screen_char_t)ch count:(int)c atX:(int)x Y:(int)y
{
  int i;
  screen_char_t *s;

  NSDebugLLog(@"ts", @"putChar: '%c' %02x %02x count: %i at: %i:%i", ch.ch, ch.color, ch.attr, c, x,
              y);

  if (y < 0 || y >= screen_height) {
    return;
  }
  if (x + c > screen_width) {
    c = screen_width - x;
  }
  if (x < 0) {
    c -= x;
    x = 0;
  }
  s = &SCREEN(x, y);
  ch.attr |= 0x80;
  for (i = 0; i < c; i++) {
    *s++ = ch;
  }
  ADD_DIRTY(x, y, c, 1);
}

- (void)ts_putChar:(screen_char_t)ch count:(int)c offset:(int)ofs
{
  int i;
  screen_char_t *s;

  NSDebugLLog(@"ts", @"putChar: '%c' %02x %02x count: %i offset: %i", ch.ch, ch.color, ch.attr, c,
              ofs);

  if (ofs + c > screen_width * screen_height) {
    c = screen_width * screen_height - ofs;
  }
  if (ofs < 0) {
    c -= ofs;
    ofs = 0;
  }
  s = &SCREEN(ofs, 0);
  ch.attr |= 0x80;
  for (i = 0; i < c; i++) {
    *s++ = ch;
  }
  ADD_DIRTY(0, 0, screen_width, screen_height); /* TODO */
}

- (void)addDataToWriteBuffer:(const char *)data length:(int)len
{
  if (!len) {
    return;
  }

  if (!write_buf_len) {
    [[NSRunLoop currentRunLoop] addEvent:(void *)(intptr_t)master_fd
                                    type:ET_WDESC
                                 watcher:self
                                 forMode:NSDefaultRunLoopMode];
  }
  if ((write_buf_len + len) > write_buf_size) {
    /* Round up to nearest multiple of 512 bytes. */
    write_buf_size = (write_buf_len + len + 511) & ~511;
    write_buf = realloc(write_buf, write_buf_size);
  }
  memcpy(&write_buf[write_buf_len], data, len);
  write_buf_len += len;
}

- (void)ts_sendCString:(const char *)msg
{
  [self ts_sendCString:msg length:strlen(msg)];
}

- (void)ts_sendCString:(const char *)msg length:(int)len
{
  int l;

  if (master_fd == -1) {
    return;
  }
  if (write_buf_len) {
    [self addDataToWriteBuffer:msg length:len];
    return;
  }

  l = write(master_fd, msg, len);
  if (l != len) {
    if (errno != EAGAIN)
      NSLog(@"Unexpected error while writing: %m.");
    if (l < 0) {
      l = 0;
    }
    [self addDataToWriteBuffer:&msg[l] length:len - l];
  }
}

#pragma mark - Movement

// ---
// --- Movement
// ---
- (void)ts_gotoX:(int)x Y:(int)y
{
  NSDebugLLog(@"ts", @"goto: %i:%i", x, y);
  cursor_x = x;
  cursor_y = y;
  if (cursor_x >= screen_width) {
    cursor_x = screen_width - 1;
  }
  if (cursor_x < 0) {
    cursor_x = 0;
  }
  if (cursor_y >= screen_height) {
    cursor_y = screen_height - 1;
  }
  if (cursor_y < 0) {
    cursor_y = 0;
  }
}

- (void)ts_scrollUpTop:(int)top bottom:(int)bottom rows:(int)rows save:(BOOL)save
{
  screen_char_t *d, *s;

  NSDebugLLog(@"ts", @"scrollUp: %i:%i  rows: %i  save: %i", top, bottom, rows, save);

  if (save && (top == 0) && (bottom == screen_height)) { /* TODO? */
    int num;

    if ((curr_sb_depth + rows) > alloc_sb_depth) {
      [self resizeScrollbackBuffer:YES];
    }

    if (rows < alloc_sb_depth) {
      memmove(scrollback, &scrollback[screen_width * rows],
              sizeof(screen_char_t) * screen_width * (alloc_sb_depth - rows));
      num = rows;
    } else {
      num = alloc_sb_depth;
    }

    if (num < screen_height) {
      memmove(&scrollback[screen_width * (alloc_sb_depth - num)], screen,
              num * screen_width * sizeof(screen_char_t));
    } else {
      memmove(&scrollback[screen_width * (alloc_sb_depth - num)], screen,
              screen_height * screen_width * sizeof(screen_char_t));
      /* TODO: should this use video_erase_char? */
      memset(&scrollback[screen_width * (alloc_sb_depth - num + screen_height)], 0,
             screen_width * (num - screen_height) * sizeof(screen_char_t));
    }

    curr_sb_depth += num;
    if (curr_sb_depth > max_sb_depth) {
      curr_sb_depth = max_sb_depth;
    }
  }

  if ((top + rows) >= bottom) {
    rows = bottom - top - 1;
  }
  if (bottom > screen_height || top >= bottom || rows < 1) {
    return;
  }
  d = &SCREEN(0, top);
  s = &SCREEN(0, top + rows);

  if (current_y >= top && current_y <= bottom) {
    SCREEN(current_x, current_y).attr |= 0x80;
    shouldDrawCursor = YES;
    /*
      TODO: does this properly handle the case when the cursor is in
      an area that gets scrolled 'over'?

      now it does, but not in an optimal way. handling of this could be
      optimized in all scrolling methods, but it probably won't make
      much difference
    */
  }
  memmove(d, s, (bottom - top - rows) * screen_width * sizeof(screen_char_t));
  if (!curr_sb_position) {
    if (top == 0 && bottom == screen_height) {
      pending_scroll -= rows;
    } else {
      float x0, y0, w, h, dx, dy;

      if (pending_scroll) {
        [self _handlePendingScroll:YES];
      }

      x0 = 0;
      w = fx * screen_width;
      y0 = (top + rows) * fy;
      h = (bottom - top - rows) * fy;
      dx = 0;
      dy = top * fy;
      y0 = screen_height * fy - y0 - h;
      dy = screen_height * fy - dy - h;
      [self lockFocus];
      DPScomposite(GSCurrentContext(), border_x + x0, border_y + y0, w, h, [self gState],
                   border_x + dx, border_y + dy, NSCompositeCopy);
      [self unlockFocusNeedsFlush:NO];
      num_scrolls++;
    }
  }
  ADD_DIRTY(0, top, screen_width, bottom - top);
}

- (void)ts_scrollDownTop:(int)top bottom:(int)bottom rows:(int)rows
{
  screen_char_t *s;
  unsigned int step;

  NSDebugLLog(@"ts", @"scrollDown: %i:%i  rows: %i", top, bottom, rows);

  if (top + rows >= bottom) {
    rows = bottom - top - 1;
  }
  if (bottom > screen_height || top >= bottom || rows < 1) {
    return;
  }
  s = &SCREEN(0, top);
  step = screen_width * rows;
  if (current_y >= top && current_y <= bottom) {
    SCREEN(current_x, current_y).attr |= 0x80;
    shouldDrawCursor = YES;
  }
  memmove(s + step, s, (bottom - top - rows) * screen_width * sizeof(screen_char_t));
  if (!curr_sb_position) {
    if (top == 0 && bottom == screen_height) {
      pending_scroll += rows;
    } else {
      float x0, y0, w, h, dx, dy;

      if (pending_scroll) {
        [self _handlePendingScroll:YES];
      }
      x0 = 0;
      w = fx * screen_width;
      y0 = (top)*fy;
      h = (bottom - top - rows) * fy;
      dx = 0;
      dy = (top + rows) * fy;
      y0 = screen_height * fy - y0 - h;
      dy = screen_height * fy - dy - h;
      [self lockFocus];
      DPScomposite(GSCurrentContext(), border_x + x0, border_y + y0, w, h, [self gState],
                   border_x + dx, border_y + dy, NSCompositeCopy);
      [self unlockFocusNeedsFlush:NO];
      num_scrolls++;
    }
  }
  ADD_DIRTY(0, top, screen_width, bottom - top);
}

- (void)ts_shiftRow:(int)row at:(int)x0 delta:(int)delta
{
  screen_char_t *s, *d;
  int x1, c;
  NSDebugLLog(@"ts", @"shiftRow: %i  at: %i  delta: %i", row, x0, delta);

  if (row < 0 || row >= screen_height) {
    return;
  }
  if (x0 < 0 || x0 >= screen_width) {
    return;
  }

  if (current_y == row) {
    SCREEN(current_x, current_y).attr |= 0x80;
    shouldDrawCursor = YES;
  }

  s = &SCREEN(x0, row);
  x1 = x0 + delta;
  c = screen_width - x0;
  if (x1 < 0) {
    x0 -= x1;
    c += x1;
    x1 = 0;
  }
  if (x1 + c > screen_width) {
    c = screen_width - x1;
  }
  d = &SCREEN(x1, row);
  memmove(d, s, sizeof(screen_char_t) * c);
  if (!curr_sb_position) {
    float cx0, y0, w, h, dx, dy;

    if (pending_scroll) {
      [self _handlePendingScroll:YES];
    }

    cx0 = x0 * fx;
    w = fx * c;
    dx = x1 * fx;

    y0 = row * fy;
    h = fy;
    dy = y0;

    y0 = screen_height * fy - y0 - h;
    dy = screen_height * fy - dy - h;
    [self lockFocus];
    DPScomposite(GSCurrentContext(), border_x + cx0, border_y + y0, w, h, [self gState],
                 border_x + dx, border_y + dy, NSCompositeCopy);
    [self unlockFocusNeedsFlush:NO];
    num_scrolls++;
  }
  ADD_DIRTY(0, row, screen_width, 1);
}

#pragma mark - TerminalScreen protocol

- (void)ts_setTitle:(NSString *)new_title type:(int)title_type
{
  NSDebugLLog(@"ts", @"setTitle: %@  type: %i", new_title, title_type);

  if (title_type == 1 || title_type == 0) {
    ASSIGN(xtermIconTitle, new_title);
  }
  if (title_type == 2 || title_type == 0) {
    ASSIGN(xtermTitle, new_title);
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:TerminalViewTitleDidChangeNotification
                                                      object:self];
}

- (int)relativeWidthOfCharacter:(unichar)ch
{
  int s;
  if (!useMultiCellGlyphs) {
    return 1;
  }
  s = ceil([font boundingRectForGlyph:ch].size.width / fx);
  if (s < 1) {
    return 1;
  }
  return s;
}

- (BOOL)useMultiCellGlyphs
{
  return useMultiCellGlyphs;
}

@end


#pragma mark - Keyboard and Mouse

//------------------------------------------------------------------------------
//--- Keyboard and Mouse events
//------------------------------------------------------------------------------

@implementation TerminalView (keyboard)

- (void)resetCursorRects
{
  const NSRect visibleRect = [self visibleRect];

  if (!NSEqualRects(NSZeroRect, visibleRect)) {
    [self addCursorRect:visibleRect cursor:[NSCursor IBeamCursor]];
  }
}

- (void)keyDown:(NSEvent *)e
{
  NSString *s = [e charactersIgnoringModifiers];

  [NSCursor setHiddenUntilMouseMoves:YES];

  NSDebugLLog(@"key", @"got key flags=%08lx  repeat=%i '%@' '%@' %4i %04x %lu %04x %lu\n",
              [e modifierFlags], [e isARepeat], [e characters], [e charactersIgnoringModifiers],
              [e keyCode], [[e characters] characterAtIndex:0], [[e characters] length],
              [[e charactersIgnoringModifiers] characterAtIndex:0],
              [[e charactersIgnoringModifiers] length]);

  if ([s length] == 1 && ([e modifierFlags] & NSShiftKeyMask)) {
    unichar ch = [s characterAtIndex:0];

    if ([e modifierFlags] & NSShiftKeyMask) {
      if (ch == NSPageUpFunctionKey) {
        [self _scrollTo:(curr_sb_position - screen_height + 1) update:YES];
        return;
      }
      if (ch == NSPageDownFunctionKey) {
        [self _scrollTo:(curr_sb_position + screen_height - 1) update:YES];
        return;
      }
    }
  }

  /* don't check until we get here so we handle scrollback page-up/down
     even when the view's idle */
  if (master_fd == -1) {
    return;
  }

  [terminalParser handleKeyEvent:e];

  // Catch Retrun and Conrtol+C key press
  // ([s characterAtIndex:0] == 0x63 && ([e modifierFlags] & NSControlKeyMask))) - Control+C
  // if ([s characterAtIndex:0] == 0xd) {
    // NSLog(@"Return key pressed. master_fd: %i, child_pid: %i, pgroup: %i", master_fd, child_pid,
    //       tcgetpgrp(master_fd));
  //   [[_window windowController] setDocumentEdited:[self isUserProgramRunning]];
  // }
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
  return YES;
}

- (BOOL)resignFirstResponder
{
  return YES;
}

@end


#pragma mark - Selection

//------------------------------------------------------------------------------
//--- Selection, copy/paste/services
//------------------------------------------------------------------------------

@implementation TerminalView (selection)

- (NSString *)_selectionAsString
{
  int ofs = alloc_sb_depth * screen_width;
  NSMutableString *mstr;
  NSString *tmp;
  unichar buf[32];
  unichar ch;
  int len, ws_len;
  int i, j;

  if (selection.length == 0)
    return nil;

  mstr = [[NSMutableString alloc] init];
  j = selection.location + selection.length;
  len = 0;
  for (i = selection.location; i < j; i++) {
    ws_len = 0;
    while (1) {
      if (i < 0)
        ch = scrollback[ofs + i].ch;
      else
        ch = screen[i].ch;

      if (ch != ' ' && ch != 0 && ch != MULTI_CELL_GLYPH)
        break;

      ws_len++;
      i++;

      if (i % screen_width == 0) {
        if (i > j) {
          ws_len = 0; /* make sure we break out of the outer loop */
          break;
        }
        if (len) {
          tmp = [[NSString alloc] initWithCharacters:buf length:len];
          [mstr appendString:tmp];
          DESTROY(tmp);
          len = 0;
        }
        [mstr appendString:@"\n"];
        ws_len = 0;
        continue;
      }
    }

    i -= ws_len;

    for (; i < j && ws_len; i++, ws_len--) {
      buf[len++] = ' ';
      if (len == 32) {
        tmp = [[NSString alloc] initWithCharacters:buf length:32];
        [mstr appendString:tmp];
        DESTROY(tmp);
        len = 0;
      }
    }
    if (i >= j)
      break;

    buf[len++] = ch;
    if (len == 32) {
      tmp = [[NSString alloc] initWithCharacters:buf length:32];
      [mstr appendString:tmp];
      DESTROY(tmp);
      len = 0;
    }
  }

  if (len) {
    tmp = [[NSString alloc] initWithCharacters:buf length:len];
    [mstr appendString:tmp];
    DESTROY(tmp);
  }

  return AUTORELEASE(mstr);
}

- (void)_setSelection:(struct selection_range)s
{
  int i, j, ofs2;

  if (s.location < -curr_sb_depth * screen_width) {
    s.length += curr_sb_depth * screen_width + s.location;
    s.location = -curr_sb_depth * screen_width;
  }
  if (s.location + s.length > screen_width * screen_height) {
    s.length = screen_width * screen_height - s.location;
  }

  if (!s.length && !selection.length)
    return;
  if (s.length == selection.length && s.location == selection.location)
    return;

  ofs2 = alloc_sb_depth * screen_width;

  j = selection.location + selection.length;
  if (j > s.location)
    j = s.location;

  for (i = selection.location; i < j && i < 0; i++) {
    scrollback[ofs2 + i].attr &= 0xbf;
    scrollback[ofs2 + i].attr |= 0x80;
  }
  for (; i < j; i++) {
    screen[i].attr &= 0xbf;
    screen[i].attr |= 0x80;
  }

  i = s.location + s.length;
  if (i < selection.location)
    i = selection.location;
  j = selection.location + selection.length;
  for (; i < j && i < 0; i++) {
    scrollback[ofs2 + i].attr &= 0xbf;
    scrollback[ofs2 + i].attr |= 0x80;
  }
  for (; i < j; i++) {
    screen[i].attr &= 0xbf;
    screen[i].attr |= 0x80;
  }

  i = s.location;
  j = s.location + s.length;
  for (; i < j && i < 0; i++) {
    if (!(scrollback[ofs2 + i].attr & 0x40))
      scrollback[ofs2 + i].attr |= 0xc0;
  }
  for (; i < j; i++) {
    if (!(screen[i].attr & 0x40))
      screen[i].attr |= 0xc0;
  }

  selection = s;
  draw_all = 2;
  [self setNeedsLazyDisplayInRect:[self bounds]];
}

- (void)_clearSelection
{
  struct selection_range s;
  s.location = s.length = 0;
  [self _setSelection:s];
}

// Menu item "Edit > Copy"
- (void)copy:(id)sender
{
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  NSString *s = [self _selectionAsString];
  if (!s) {
    NSBeep();
    return;
  }
  [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
  [pb setString:s forType:NSStringPboardType];
}

// Menu item "Edit > Paste"
- (void)paste:(id)sender
{
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  NSString *type;
  NSString *str;

  type = [pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
  if (!type)
    return;

  str = [pb stringForType:NSStringPboardType];
  if (str)
    [terminalParser sendString:str];
}

// Menu item "Edit > Paste Selection"
- (void)pasteSelection:(id)sender
{
  NSString *s = [self _selectionAsString];
  if (!s) {
    NSBeep();
    return;
  }
  if (s)
    [terminalParser sendString:s];
}

// Menu item "Font > Copy Font"
- (void)copyFont:(id)sender
{
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSFontPboard];
  NSDictionary *dict;
  NSData *data;

  if (pb)
    [pb declareTypes:[NSArray arrayWithObject:NSFontPboardType] owner:nil];
  else
    return;

  // NSLog(@"Copy font to Pasteboard: %@", pb);
  dict = [NSDictionary dictionaryWithObject:font forKey:@"NSFont"];
  if (dict != nil) {
    data = [NSArchiver archivedDataWithRootObject:dict];
    if (data != nil) {
      [pb setData:data forType:NSFontPboardType];
      // NSLog(@"Terminal: %@ | Font copied: %@", [self deviceName], data);
    }
  }
}

// Menu item "Font > Paste Font"
- (void)pasteFont:(id)sender
{
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSFontPboard];
  NSData *data;
  NSDictionary *dict;

  if (pb)
    data = [pb dataForType:NSFontPboardType];
  else
    return;

  if (data)
    dict = [NSUnarchiver unarchiveObjectWithData:data];
  else
    return;

  // NSLog(@"TerminalView: %@ pasted font with attributes: %@",
  //       [self deviceName], dict);

  if (dict != nil) {
    NSFont *f = [dict objectForKey:@"NSFont"];
    if (f != nil) {
      [(TerminalWindowController *)[[self window] delegate] setFont:f updateWindowSize:YES];
    }
  }
}

// Menu item "Edit > Select All"
- (void)selectAll:(id)sender
{
  struct selection_range s;
  s.location = 0 - (curr_sb_depth * screen_width);
  s.length = (screen_width * screen_height) + (curr_sb_depth * screen_width);
  [self _setSelection:s];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pb types:(NSArray *)t
{
  int i;
  NSString *s;

  s = [self _selectionAsString];
  if (!s) {
    NSBeep();
    return NO;
  }

  [pb declareTypes:t owner:self];
  for (i = 0; i < [t count]; i++) {
    if ([[t objectAtIndex:i] isEqual:NSStringPboardType]) {
      [pb setString:s forType:NSStringPboardType];
      return YES;
    }
  }
  return NO;
}

/* TODO: is it really necessary to implement this? */
- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pb
{
  return YES;
}

- (id)validRequestorForSendType:(NSString *)st returnType:(NSString *)rt
{
  if (!selection.length)
    return nil;
  if (st != nil && ![st isEqual:NSStringPboardType])
    return nil;
  if (rt != nil)
    return nil;
  return self;
}

/* Return the range we should select for the given position and granularity:
   0   characters
   1   words
   2   lines
*/
- (struct selection_range)_selectionRangeAt:(int)pos granularity:(int)g
{
  struct selection_range s;

  if (g == 3) { /* select lines */
    int l = floor(pos / (float)screen_width);
    s.location = l * screen_width;
    s.length = screen_width;
    return s;
  }

  if (g == 2) { /* select words */
    int ofs = alloc_sb_depth * screen_width;
    unichar ch, ch2;
    NSCharacterSet *cs;
    int i, j;

    if (pos < 0)
      ch = scrollback[ofs + pos].ch;
    else
      ch = screen[pos].ch;
    if (ch == 0)
      ch = ' ';

    /* try to find a character set for this character */
    cs = [NSCharacterSet alphanumericCharacterSet];
    if ([additionalWordCharacters length] > 0) {
      NSMutableCharacterSet *mcs =
          [NSMutableCharacterSet characterSetWithCharactersInString:additionalWordCharacters];
      [mcs formUnionWithCharacterSet:cs];
      cs = mcs;
    }
    if (![cs characterIsMember:ch])
      cs = [NSCharacterSet punctuationCharacterSet];
    if (![cs characterIsMember:ch])
      cs = [NSCharacterSet whitespaceCharacterSet];
    if (![cs characterIsMember:ch]) {
      s.location = pos;
      s.length = 1;
      return s;
    }

    /* search the line backwards for a boundary */
    j = floor(pos / (float)screen_width);
    j *= screen_width;
    for (i = pos - 1; i >= j; i--) {
      if (i < 0)
        ch2 = scrollback[ofs + i].ch;
      else
        ch2 = screen[i].ch;
      if (ch2 == 0)
        ch2 = ' ';

      if (![cs characterIsMember:ch2])
        break;
    }
    s.location = i + 1;

    /* and forwards... */
    j += screen_width;
    for (i = pos + 1; i < j; i++) {
      if (i < 0)
        ch2 = scrollback[ofs + i].ch;
      else
        ch2 = screen[i].ch;
      if (ch2 == 0)
        ch2 = ' ';

      if (![cs characterIsMember:ch2])
        break;
    }
    s.length = i - s.location;
    return s;
  }

  s.location = pos;
  s.length = 0;

  return s;
}

- (void)mouseDown:(NSEvent *)e
{
  int ofs0, ofs1, first;
  NSPoint p;
  struct selection_range s;
  int g;
  struct selection_range r0, r1;

  r0.location = r0.length = 0;
  r1 = r0;
  first = YES;
  ofs0 = 0; /* get compiler to shut up */
  g = [e clickCount];
  while ([e type] != NSLeftMouseUp) {
    p = [e locationInWindow];

    p = [self convertPoint:p fromView:nil];
    p.x = floor((p.x - border_x) / fx);
    if (p.x < 0)
      p.x = 0;
    if (p.x >= screen_width)
      p.x = screen_width - 1;
    p.y = ceil((p.y - border_y) / fy);
    if (p.y < -1)
      p.y = -1;
    if (p.y > screen_height)
      p.y = screen_height;
    p.y = screen_height - p.y + curr_sb_position;
    ofs1 = ((int)p.x) + ((int)p.y) * screen_width;

    r1 = [self _selectionRangeAt:ofs1 granularity:g];
    if (first) {
      ofs0 = ofs1;
      first = 0;
      r0 = r1;
    }

    NSDebugLLog(@"select", @"ofs %i %i (%i+%i) (%i+%i)\n", ofs0, ofs1, r0.location, r0.length,
                r1.location, r1.length);

    if (ofs1 > ofs0) {
      s.location = r0.location;
      s.length = r1.location + r1.length - r0.location;
    } else {
      s.location = r1.location;
      s.length = r0.location + r0.length - r1.location;
    }

    // Select last character in line if mouse at edge of window
    if ((s.location + s.length) % screen_width == screen_width - 1)
      s.length += 1;

    [self _setSelection:s];
    [self displayIfNeeded];

    e = [NSApp nextEventMatchingMask:(NSLeftMouseDownMask | NSLeftMouseUpMask |
                                      NSLeftMouseDraggedMask | NSMouseMovedMask)
                           untilDate:[NSDate distantFuture]
                              inMode:NSEventTrackingRunLoopMode
                             dequeue:YES];
  }

  if (selection.length) {
    [self writeSelectionToPasteboard:[NSPasteboard pasteboardWithName:@"Selection"]
                               types:[NSArray arrayWithObject:NSStringPboardType]];
  }
}

- (void)otherMouseUp:(NSEvent *)e
{
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:@"Selection"];
  NSString *type;
  NSString *str;

  type = [pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
  if (!type) {
    return;
  }
  str = [pb stringForType:NSStringPboardType];
  if (str) {
    [terminalParser sendString:str];
  }
}

@end


#pragma mark - Input/Output

//------------------------------------------------------------------------------
//--- Handle master_fd
//------------------------------------------------------------------------------

@implementation TerminalView (Input_Output)

- (void)readData
{
  char buf[256];
  int size, total, i;

  total = 0;
  num_scrolls = 0;
  dirty.x0 = -1;

  current_x = cursor_x;
  current_y = cursor_y;

  // If previous run required update do it again to catch forked subprocess.
  if (shouldUpdateTitlebar != NO) {
    [self updateProgramPath];
  }
  shouldUpdateTitlebar = NO;
  
  [self _clearSelection]; /* TODO? */

  NSDebugLLog(@"term", @"receiving output");

  while (1) {
    size = read(master_fd, buf, sizeof(buf));
    if (size < 0 && errno == EAGAIN)
      break;

    // Program exited: print message, send notification and return.
    // TODO: get program exit code.
    if (size <= 0) {
      NSString *msg;
      int i, c;
      unichar ch;

      [self closeProgram];

      [terminalParser processByte:'\n'];
      [terminalParser processByte:'\r'];
      msg = _(@"[Process exited]");
      c = [msg length];
      for (i = 0; i < c; i++) {
        ch = [msg characterAtIndex:i];
        if (ch < 256) { /* TODO */
          [terminalParser processByte:ch];
        }
      }
      [terminalParser processByte:'\n'];
      [terminalParser processByte:'\r'];

      // Sending this notification might cause us to be deallocated, in
      // which case we can't let the rest of code here run (and we'd rather
      // not to avoid a pointless update of the screen). To detect this, we
      // retain ourself before the call and check the retaincount after.
      // [self retain];
      [[NSNotificationCenter defaultCenter] postNotificationName:TerminalViewBecameIdleNotification
                                                          object:self];
      // if ([self retainCount] == 1)
      //   { /* we only have our own retain left, so we release ourself
      //        (causing us to be deallocated) and return */
      //     [self release];
      //     return;
      //   }
      // [self release];

      break;
    }

    for (i = 0; i < size; i++) {
      [terminalParser processByte:buf[i]];
      // Line Feed, Vertical Tabulation, Form Feed, Carriage Return
      if (isActivityMonitorEnabled &&
          (buf[i] == 10 || buf[i] == 11 || buf[i] == 12 || buf[i] == 13)) {
        // fprintf(stderr, "%i\n", buf[i]);
        shouldUpdateTitlebar = YES;
      }
    }
    total += size;
    /*
      Don't get stuck processing input forever; give other terminal windows
      and the user a chance to do things. The numbers affect latency versus
      throughput. High numbers means more input is processed before the
      screen is updated, leading to higher throughput but also to more
      'jerky' updates. Low numbers would give smoother updating and less
      latency, but throughput goes down.

      TODO: tweak more? seems pretty good now
    */
    if (total >= 8192 || (num_scrolls + abs(pending_scroll)) > 10)
      break;
  }

  if (shouldUpdateTitlebar != NO) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
      [self updateProgramPath];
    });
  }

  if (cursor_x != current_x || cursor_y != current_y) {
    ADD_DIRTY(current_x, current_y, 1, 1);
    SCREEN(current_x, current_y).attr |= 0x80;
    ADD_DIRTY(cursor_x, cursor_y, 1, 1);
    shouldDrawCursor = YES;
  }

  NSDebugLLog(@"term", @"done (%i %i) (%i %i)\n", dirty.x0, dirty.y0, dirty.x1, dirty.y1);

  if (dirty.x0 >= 0) {
    NSRect dr;

    // NSLog(@"dirty=(%i %i)-(%i %i)\n",dirty.x0,dirty.y0,dirty.x1,dirty.y1);
    dr.origin.x = dirty.x0 * fx;
    dr.origin.y = dirty.y0 * fy;
    dr.size.width = (dirty.x1 - dirty.x0) * fx;
    dr.size.height = (dirty.y1 - dirty.y0) * fy;
    dr.origin.y = fy * screen_height - (dr.origin.y + dr.size.height);
    // NSLog(@"-> dirty=(%g %g)+(%g
    // %g)\n",dirty.origin.x,dirty.origin.y,dirty.size.width,dirty.size.height);
    dr.origin.x += border_x;
    dr.origin.y += border_y;
    [self setNeedsLazyDisplayInRect:dr];

    if (curr_sb_position != 0) { /* TODO */
      if (shouldScrollBottomOnInput == YES) {
        curr_sb_position = 0;
      }
      [self setNeedsDisplay:YES];
    }

    [self _updateScroller];
  }
}

- (void)writeData
{
  // NSLog(@"Will write data");
  int l, new_size;
  l = write(master_fd, write_buf, write_buf_len);
  if (l < 0) {
    if (errno != EAGAIN) {
      NSLog(@"Unexpected error while writing: %m.");
    }
    return;
  }
  memmove(write_buf, &write_buf[l], write_buf_len - l);
  write_buf_len -= l;

  /* If less than half the buffer is empty, reallocate it, but never free
     it completely. */
  new_size = (write_buf_len + 511) & ~511;
  if (!new_size)
    new_size = 512;
  if (new_size <= write_buf_size / 2) {
    write_buf_size = new_size;
    write_buf = realloc(write_buf, write_buf_size);
  }

  if (!write_buf_len) {
    [[NSRunLoop currentRunLoop] removeEvent:(void *)(intptr_t)master_fd
                                       type:ET_WDESC
                                    forMode:NSDefaultRunLoopMode
                                        all:YES];
  }
}

// RunLoopEvents protocol method
- (void)receivedEvent:(void *)data
                 type:(RunLoopEventType)type
                extra:(void *)extra
              forMode:(NSString *)mode
{
  if (type == ET_WDESC) {
    [self writeData];
  } else if (type == ET_RDESC) {
    [self readData];
  }
}

- (void)closeProgram
{
  if (master_fd == -1)
    return;
  NSDebugLLog(@"pty", @"closing master fd=%i\n", master_fd);

  [[NSRunLoop currentRunLoop] removeEvent:(void *)(intptr_t)master_fd
                                     type:ET_RDESC
                                  forMode:NSDefaultRunLoopMode
                                      all:YES];
  [[NSRunLoop currentRunLoop] removeEvent:(void *)(intptr_t)master_fd
                                     type:ET_WDESC
                                  forMode:NSDefaultRunLoopMode
                                      all:YES];
  write_buf_len = write_buf_size = 0;
  free(write_buf);
  write_buf = NULL;
  close(master_fd);
  master_fd = -1;
}

- (int)runProgram:(NSString *)path
    withArguments:(NSArray *)args
      inDirectory:(NSString *)directory
     initialInput:(NSString *)d
             arg0:(NSString *)arg0
{
  int pid;
  struct winsize ws;
  NSRunLoop *rl;
  const char *cpath;
  const char *cargs[[args count] + 2];
  const char *cdirectory;
  char *tty_name;
  int i;
  int pipefd[2];
  int flags;

  NSDebugLLog(@"pty", @"-runProgram: %@ withArguments: %@ initialInput: %@", path, args, d);

  [self closeProgram];

  cdirectory = [directory cString];

  cpath = [path cString];
  programPath = [[path lastPathComponent] copy];
  if (arg0) {
    cargs[0] = [arg0 cString];
  } else {
    cargs[0] = cpath;
  }
  for (i = 0; i < [args count]; i++) {
    cargs[i + 1] = [[args objectAtIndex:i] cString];
  }
  cargs[i + 1] = NULL;

  if (d) {
    if (pipe(pipefd)) {
      NSLog(@"Unable to open pipe for input: %m.");
      return -1;
    }
    NSDebugLLog(@"pty", @"creating pipe for initial data, got %i %i", pipefd[0], pipefd[1]);
  }

  ws.ws_row = screen_height;
  ws.ws_col = screen_width;
  tty_name = malloc(128 * sizeof(char));  // 128 should be enough?
  pid = forkpty(&master_fd, tty_name, NULL, &ws);
  if (pid < 0) {
    NSLog(@"Unable to fork: %m.");
    return pid;
  }

  if (pid == 0) {  // child process
    if (d) {
      close(pipefd[1]);
      dup2(pipefd[0], 0);
    }

    if (cdirectory && (chdir(cdirectory) < 0)) {
      fprintf(stderr, "Unable do set directory: %s\n", cdirectory);
    }

    putenv("TERM=linux");
    putenv("TERM_PROGRAM=GNUstep_Terminal");

    // fprintf(stderr, "Child process terminal: %s\n", ttyname(0));

    execvp(cpath, (char *const *)cargs);

    fprintf(stderr, "Unable to spawn process '%s': %m!", cpath);
    exit(1);
  }

  NSDebugLLog(@"pty", @"forked child %i, fd %i", pid, master_fd);

  /* Set non-blocking mode for the descriptor. */
  flags = fcntl(master_fd, F_GETFL, 0);
  if (flags == -1) {
    NSLog(@"Unable to set non-blocking mode: %m.");
  } else {
    flags |= O_NONBLOCK;
    fcntl(master_fd, F_SETFL, flags);
  }

  rl = [NSRunLoop currentRunLoop];
  [rl addEvent:(void *)(intptr_t)master_fd type:ET_RDESC watcher:self forMode:NSDefaultRunLoopMode];
  [rl addEvent:(void *)(intptr_t)master_fd type:ET_WDESC watcher:self forMode:NSDefaultRunLoopMode];

  [[NSNotificationCenter defaultCenter] postNotificationName:TerminalViewBecameNonIdleNotification
                                                      object:self];

  // Setup titles
  DESTROY(xtermTitle);
  childTerminalName = [[NSString stringWithCString:tty_name] retain];
  free(tty_name);

  ASSIGN(xtermIconTitle, path);

  [[NSNotificationCenter defaultCenter] postNotificationName:TerminalViewTitleDidChangeNotification
                                                      object:self];

  // Send initial input
  if (d) {
    const char *s = [d UTF8String];
    close(pipefd[0]);
    write(pipefd[1], s, strlen(s));
    close(pipefd[1]);
  }

  child_pid = pid;

  return pid;
}

- (int)runProgram:(NSString *)path
    withArguments:(NSArray *)args
     initialInput:(NSString *)d
{
  return [self runProgram:path withArguments:args inDirectory:nil initialInput:d arg0:path];
}

- (int)runShell
{
  NSString *arg0;
  NSString *path;
  NSArray *args = nil;

  path = [defaults shell];
  args = [path componentsSeparatedByString:@" "];
  if ([args count] > 1) {
    path = [args objectAtIndex:0];
    args = [args subarrayWithRange:NSMakeRange(1, [args count] - 1)];
  } else {
    args = nil;
  }

  if ([defaults loginShell]) {
    arg0 = [@"-" stringByAppendingString:path];
  } else {
    arg0 = path;
  }

  return [self runProgram:path withArguments:args inDirectory:nil initialInput:nil arg0:arg0];
}

@end


#pragma mark - Drag and Drop

//------------------------------------------------------------------------------
//--- Drag and Drop support
//------------------------------------------------------------------------------

@implementation TerminalView (drag_n_drop)

static int handled_mask = (NSDragOperationCopy | NSDragOperationPrivate | NSDragOperationGeneric);

- (unsigned int)draggingEntered:(id<NSDraggingInfo>)sender
{
  NSArray *types = [[sender draggingPasteboard] types];
  unsigned int mask = [sender draggingSourceOperationMask];

  NSDebugLLog(@"dragndrop", @"TerminalView draggingEntered mask=%x types=%@", mask, types);

  if (!(mask & handled_mask)) {
    return NSDragOperationNone;
  }

  if ([types containsObject:NSFilenamesPboardType] || [types containsObject:NSStringPboardType]) {
    return NSDragOperationCopy;
  }

  return NSDragOperationNone;
}

/* TODO: should I really have to implement this? */
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
  NSDebugLLog(@"dragndrop", @"preparing for drag");
  return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSArray *types = [pb types];
  unsigned int mask = [sender draggingSourceOperationMask];

  NSDebugLLog(@"dragndrop", @"performDrag %x %@", mask, types);

  if (!(mask & handled_mask)) {
    return NO;
  }

  if ([types containsObject:NSFilenamesPboardType]) {
    NSArray *data;
    int i, c;

    data = [pb propertyListForType:NSFilenamesPboardType];
    if (!data) {
      data = [NSUnarchiver unarchiveObjectWithData:[pb dataForType:NSFilenamesPboardType]];
    }

    // Insert space if previous character is not space
    if (SCREEN(cursor_x - 1, cursor_y).ch != ' ') {
      [terminalParser sendString:@" "];
    }

    c = [data count];
    for (i = 0; i < c; i++) {
      [terminalParser sendString:[data objectAtIndex:i]];
      if (i < (c - 1)) {
        [terminalParser sendString:@" "];
      }
    }
    return YES;
  }

  if ([types containsObject:NSStringPboardType]) {
    NSString *str = [pb stringForType:NSStringPboardType];
    [terminalParser sendString:str];
    return YES;
  }

  return NO;
}

@end


#pragma mark - Main class

//------------------------------------------------------------------------------
//--- Misc. stuff
//------------------------------------------------------------------------------

@implementation TerminalView

#pragma mark - Init and dealloc
// ---
// Init and dealloc
// ---

// Allocate scrollback buffer to new number of lines.
//
// General idea:
// - initially allocate memory for SCROLLBACK_CHANGE_STEP terminal screens
// - realloc scrollback buffer by SCROLLBACK_CHANGE_STEP screens until max_sb_depth will be reached
// - on window resize or preference change buffer size should be recalculated
//
// Grow/shrink minimum step is 1 screen.
// Depth (_depth in var names) is a number of lines.
// Size (_size in var names) is a number of characters.
//
// Changes: scrollback, alloc_sb_depth. May change curr_sb_depth on buffer shrinking.
- (BOOL)changeScrollBackBufferDepth:(int)lines
{
  screen_char_t *new_scrollback;
  int char_size = sizeof(screen_char_t);
  int new_sb_depth;  // lines
  int new_sb_size;   // characters

  // There's nothing to do here
  if (alloc_sb_depth == lines || lines == 0) {
    return YES;
  }

  // Check `lines` value for limits
  if (lines < alloc_sb_depth) {
    new_sb_depth = lines;
  } else if ((lines * screen_width) >= SCROLLBACK_MAX) {
    new_sb_depth = SCROLLBACK_MAX / screen_width;
  } else {
    new_sb_depth = alloc_sb_depth + (screen_height * SCROLLBACK_CHANGE_STEP);
  }

  if (new_sb_depth > max_sb_depth) {
    new_sb_depth = max_sb_depth;
  }

  new_sb_size = char_size * screen_width * new_sb_depth;

  // Memory operations
  if (scrollback == NULL || alloc_sb_depth == 0) {  // Initialize
    new_scrollback = malloc(new_sb_size);
    if (new_scrollback == NULL) {
      NSLog(@"EROOR: failed to allocate scrollback buffer of depth %d (error: %s)", new_sb_depth,
            strerror(errno));
      return NO;
    }
  } else {  // Grow or shrink
    int used_sb_size = char_size * curr_sb_depth * screen_width;
    int used_sb_start = (char_size * alloc_sb_depth * screen_width) - used_sb_size;
    screen_char_t *used_sb_copy = malloc(used_sb_size);

    // Save scrollback contents
    memcpy(used_sb_copy, &scrollback[used_sb_start], used_sb_size);

    // fprintf(stderr, "==========================================> used_sb_copy: \n");
    // for (int i = 0; i < (curr_sb_depth * screen_width); i++) {
    //   fprintf(stderr, "%c", used_sb_copy[i].ch);
    // }
    // fprintf(stderr, "<==========================================\n");

    new_scrollback = realloc(scrollback, new_sb_size);
    if (new_scrollback == NULL) {
      NSLog(@"ERROR: failed to re-allocate scrollback buffer to %d lines (error: %s)\n",
            new_sb_depth, strerror(errno));
      free(used_sb_copy);
      return NO;
    }
    memset(new_scrollback, 0, new_sb_size);

    // Restore scrollback contents
    int new_sb_offset;
    int used_sb_offset;
    
    if (used_sb_size > new_sb_size) { // Shrink
      new_sb_offset = 0;
      used_sb_offset = (used_sb_size / char_size) - (new_sb_size / char_size);
      used_sb_size = new_sb_size;
    } else { // Grow
      new_sb_offset = (new_sb_size / char_size) - (used_sb_size / char_size);
      used_sb_offset = 0;
    }

    // fprintf(stderr, "new_sb_size: %i, used_sb_size: %i, new chars: %lu, used chars: %lu\n",
    //         new_sb_size, used_sb_size, new_sb_size/sizeof(screen_char_t),
    //         used_sb_size/sizeof(screen_char_t));

    memcpy(&new_scrollback[new_sb_offset], &used_sb_copy[used_sb_offset], used_sb_size);
    free(used_sb_copy);
  }

  // Debugging info
  if (scrollback == NULL || alloc_sb_depth == 0) {
    NSDebugLLog(@"Scrollback", @"Scrollback buffer initialized to %d of %d lines.", new_sb_depth, lines);
  } else if (new_sb_depth < alloc_sb_depth) {
    NSDebugLLog(@"Scrollback", @"Scrollback buffer had shrinked from %d to %d lines.", alloc_sb_depth, new_sb_depth);
  } else {
    NSDebugLLog(@"Scrollback", @"Scrollback buffer had grown from %d to %d lines.", alloc_sb_depth, new_sb_depth);
  }

  scrollback = new_scrollback;
  alloc_sb_depth = new_sb_depth;

  // If buffer size shrinks and used buffer greater than allocated scroll bottom
  // to omit crashes and garbage on screen redraw.
  if (curr_sb_depth > new_sb_depth) {
    curr_sb_depth = new_sb_depth;
    [self _updateScroller];
    [self _scrollTo:curr_sb_position update:YES];
  }

  return YES;
}

- (BOOL)resizeScrollbackBuffer:(BOOL)shouldGrow
{
  int new_sb_depth;
  int change_size = screen_height * SCROLLBACK_CHANGE_STEP;

  if (alloc_sb_depth == max_sb_depth || alloc_sb_depth == (SCROLLBACK_MAX / screen_width)) {
    return NO;
  }

  new_sb_depth = alloc_sb_depth + (shouldGrow ? change_size : -change_size);

  if (new_sb_depth > max_sb_depth) {
    new_sb_depth = max_sb_depth;
  }

  return [self changeScrollBackBufferDepth:new_sb_depth];
}

- initWithFrame:(NSRect)frame
{
  if (!(self = [super initWithFrame:frame])) {
    return nil;
  }

  screen_width = [defaults windowWidth];
  screen_height = [defaults windowHeight];

  [self setFont:[defaults terminalFont]];
  if ([defaults useBoldTerminalFont]) {
    [self setBoldFont:[Defaults boldTerminalFontForFont:[defaults terminalFont]]];
  } else {
    [self setBoldFont:[defaults terminalFont]];
  }

  [self setAdditionalWordCharacters:[defaults wordCharacters]];

  useMultiCellGlyphs = [defaults useMultiCellGlyphs];

  screen = malloc(sizeof(screen_char_t) * screen_width * screen_height);
  memset(screen, 0, sizeof(screen_char_t) * screen_width * screen_height);
  draw_all = 2;

  shouldScrollBottomOnInput = [defaults scrollBottomOnInput];
  max_sb_depth = [defaults scrollBackLines];
  [self resizeScrollbackBuffer:YES];

  terminalParser = [[TerminalParser_Linux alloc] initWithTerminalScreen:self
                                                                  width:screen_width
                                                                 height:screen_height];
  master_fd = -1;

  [self registerForDraggedTypes:@[ NSFilenamesPboardType, NSStringPboardType ]];

  childTerminalName = nil;

  [self updateColors:nil];
  [self setCursorStyle:[defaults cursorStyle]];

  isActivityMonitorEnabled = [defaults isActivityMonitorEnabled];

  return self;
}

- initWithPreferences:(Defaults *)preferences
{
  defaults = preferences;
  return [self initWithFrame:NSZeroRect];
}

- (Defaults *)preferences
{
  return defaults;
}

- (NSObject<TerminalParser> *)terminalParser
{
  return terminalParser;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [self closeProgram];

  DESTROY(terminalParser);

  [scroller setTarget:nil];
  DESTROY(scroller);

  free(screen);
  free(scrollback);
  screen = NULL;
  scrollback = NULL;

  DESTROY(additionalWordCharacters);
  DESTROY(font);
  DESTROY(boldFont);

  DESTROY(childTerminalName);
  DESTROY(xtermTitle);
  DESTROY(xtermIconTitle);

  DESTROY(programPath);

  [super dealloc];
}

#pragma mark - Resizing
// ---
// Resize
// ---
- (void)_resizeTerminalTo:(NSSize)size
{
  int nsx, nsy;
  struct winsize ws;
  screen_char_t *nscreen, *new_sb_buffer;
  int iy, ny;
  int copy_sx;

  nsx = (size.width - border_x) / fx;
  nsy = (size.height - border_y) / fy;

  NSDebugLLog(@"term", @"_resizeTerminalTo: (%g %g) %i %i (%g %g)\n", size.width, size.height, nsx,
              nsy, nsx * fx, nsy * fy);

  if (shouldIgnoreResize) {
    NSDebugLLog(@"term", @"ignored");
    return;
  }

  if (nsx < 1) {
    nsx = 1;
  }
  if (nsy < 1) {
    nsy = 1;
  }

  /* Do a complete redraw anyway. Even though we don't really need it,
     the resize might have caused other things to overwrite our part of the
     window. */
  if (nsx == screen_width && nsy == screen_height) {
    draw_all = 2;
    return;
  }

  [self _clearSelection]; /* TODO? */

  // Prepare new screen and history buffer
  nscreen = malloc(nsx * nsy * sizeof(screen_char_t));
  new_sb_buffer = malloc(nsx * alloc_sb_depth * sizeof(screen_char_t));
  if (!nscreen || !new_sb_buffer) {
    NSLog(@"Failed to allocate screen buffer!");
    if (nscreen)
      free(nscreen);
    if (new_sb_buffer)
      free(new_sb_buffer);
    return;
  }
  memset(nscreen, 0, sizeof(screen_char_t) * nsx * nsy);
  memset(new_sb_buffer, 0, sizeof(screen_char_t) * nsx * alloc_sb_depth);

  copy_sx = screen_width;
  if (copy_sx > nsx) {
    copy_sx = nsx;
  }

  // NSLog(@"copy %i+%i %i  (%ix%i)-(%ix%i)\n",start,num,copy_sx,sx,sy,nsx,nsy);

  /* TODO: handle resizing and scrollback improve? */
  // sy,sx - current screen height(lines) and width(chars)
  // nsy,nsx - screen height(lines) and width(chars) after resize
  // curr_sb_depth - current scroll buffer length (lines)
  // cursor_y - vertical position of cursor (starts from 0)

  // fprintf(stderr,
  //         "***> curr_sb_depth=%i, alloc_sb_depth=%i, sy=%i, nsy=%i cursor_y=%i\n",
  //         curr_sb_depth, alloc_sb_depth, sy, nsy, cursor_y);

  // what amount of lines shifted?
  // value is positive if gap between last line and view bottom exist
  // value is negative if resized view overlap bottom lines
  int line_shift = nsy - (cursor_y + 1);

  // increase with scrollbuffer
  if ((screen_height <= nsy) && (curr_sb_depth > 0) && (line_shift > curr_sb_depth)) {
    line_shift = curr_sb_depth;
  }

  // NOTE: this part of code is not very short, but it's clear and simple.
  // Leave it as is.
  for (iy = -curr_sb_depth; iy < screen_height; iy++) {
    screen_char_t *src, *dst;

    // what is direction of resize: increase or descrease?
    if (screen_height > nsy) {  // decrease
      // cut bottom of 'screen' or not?
      if (cursor_y < nsy) {  // cut
        ny = iy;
      } else {  // not cut
        ny = iy + line_shift;
      }
    } else {  // increase
      // do we have scrollback buffer filled?
      if (curr_sb_depth > 0) {  // YES
        ny = iy + line_shift;
      } else {  // NO
        ny = iy;
      }
    }
    if (ny >= nsy) {
      break;
    }
    if (ny < -alloc_sb_depth) {
      continue;
    }

    // fprintf(stderr, "* iy=%i ny=%i\n", iy, ny);

    if (iy < 0) {
      src = &scrollback[screen_width * (alloc_sb_depth + iy)];
    } else {
      src = &screen[screen_width * iy];
    }
    if (ny < 0) {
      dst = &new_sb_buffer[nsx * (alloc_sb_depth + ny)];
    } else {
      dst = &nscreen[nsx * ny];
    }
    memcpy(dst, src, copy_sx * sizeof(screen_char_t));
  }

  // update cursor y position
  if ((screen_height < nsy) && (curr_sb_depth > 0)) {
    cursor_y = cursor_y + line_shift;
  }

  // Calculate new scroll buffer length
  if (nsy <= cursor_y || screen_height < nsy) {
    curr_sb_depth = curr_sb_depth - line_shift;
  }
  if (curr_sb_depth > alloc_sb_depth) {
    curr_sb_depth = alloc_sb_depth;
  }
  if (curr_sb_depth < 0) {
    curr_sb_depth = 0;
  }
  // fprintf(stderr,
  //         "***< curr_sb_depth=%i, alloc_sb_depth=%i, sy=%i, nsy=%i cursor_y=%i\n",
  //         curr_sb_depth, alloc_sb_depth, sy, nsy, cursor_y);

  screen_width = nsx;
  screen_height = nsy;
  free(screen);
  free(scrollback);
  screen = nscreen;
  scrollback = new_sb_buffer;

  if (cursor_x > screen_width) {
    cursor_x = screen_width - 1;
  }
  if (cursor_y > screen_height) {
    cursor_y = screen_height - 1;
  }
  // fprintf(stderr,
  //         "***< curr_sb_depth=%i, alloc_sb_depth=%i, sy=%i, nsy=%i cursor_y=%i line_shift=%i\n",
  //         curr_sb_depth, alloc_sb_depth, sy, nsy, cursor_y, line_shift);

  [self _updateScroller];

  [terminalParser setTerminalScreenWidth:screen_width height:screen_height cursorY:cursor_y];

  if (master_fd != -1) {
    ws.ws_row = nsy;
    ws.ws_col = nsx;
    ioctl(master_fd, TIOCSWINSZ, &ws);
  }

  [self setNeedsDisplay:YES];
}

- (void)setFrame:(NSRect)frame
{
  [super setFrame:frame];
  [self _resizeTerminalTo:frame.size];

  [[NSNotificationCenter defaultCenter] postNotificationName:TerminalViewSizeDidChangeNotification
                                                      object:self];
}

- (void)setFrameSize:(NSSize)size
{
  [super setFrameSize:size];
  [self _resizeTerminalTo:size];

  [[NSNotificationCenter defaultCenter] postNotificationName:TerminalViewSizeDidChangeNotification
                                                      object:self];
}

#pragma mark - Contents
// ---
// Contents of Terminal including scrollback buffer
//
// This is simplified version of _selectionAsString method.
// The difference is while _selectionAsString returns string with new line
// symbols at the end of Terminal window this method return plain conseqence
// of chars. This is usefull for finding substring and setting selection to
// position and length of buf[] array.
// ---
// - (NSString *)stringForRange:(struct selection_range)range
- (NSString *)stringRepresentation
{
  int ofs = alloc_sb_depth * screen_width;
  NSMutableString *mstr = [[NSMutableString alloc] init];
  NSString *tmp;
  unichar buf[32];
  unichar ch;
  int start_index, end_index;
  int len;

  if (curr_sb_depth > 0) {
    start_index = -(curr_sb_depth * screen_width);
  } else {
    start_index = 0;
  }
  end_index = screen_width * screen_height;
  // j = abs(curr_sb_depth * sx) + range.length;
  // range.length = scrollbuffer size + visible area size in terms of chars
  len = 0;
  for (int i = start_index; i < end_index; i++) {
    if (i < 0) {
      ch = scrollback[ofs + i].ch;
    } else {
      ch = screen[i].ch;
    }
    if (i >= end_index) {
      break;
    }

    buf[len++] = ch;

    if (len == 32) {
      tmp = [[NSString alloc] initWithCharacters:buf length:32];
      [mstr appendString:tmp];
      DESTROY(tmp);
      len = 0;
    }
  }

  if (len) {
    tmp = [[NSString alloc] initWithCharacters:buf length:len];
    [mstr appendString:tmp];
    DESTROY(tmp);
  }

  NSLog(@"TerminalView stringRepresentation length: %lu", [mstr length]);

  return mstr;
}

- (NSRange)selectedRange
{
  NSRange range = NSMakeRange(0, 0);

  range.length = selection.length;

  if (selection.location < 0) {
    range.location = (curr_sb_depth * screen_width) + selection.location;
  } else {
    range.location = selection.location;
  }

  return range;
}

- (void)setSelectedRange:(NSRange)range
{
  struct selection_range s;

  s.location = range.location - (curr_sb_depth * screen_width);
  s.length = range.length;

  [self _setSelection:s];
}

- (void)scrollRangeToVisible:(NSRange)range
{
  int scroll_to;

  scroll_to = ((range.location / screen_width) - curr_sb_depth);  // - sy/2;
  [self _scrollTo:scroll_to update:YES];
}


#pragma mark - Window Prefernces
// ---
// Per-window preferences
// ---

- (void)setAdditionalWordCharacters:(NSString *)str
{
  ASSIGN(additionalWordCharacters, str);
}

- (void)setFont:(NSFont *)aFont
{
  NSRect r;
  NSSize s;

  ASSIGN(font, aFont);

  s = [Defaults characterCellSizeForFont:font];
  fx = s.width;
  fy = s.height;

  r = [font boundingRectForFont];
  fx0 = -r.origin.x;
  fy0 = -r.origin.y;
  font_encoding = [font mostCompatibleStringEncoding];

  NSDebugLLog(@"term", @"Bounding (%g %g)+(%g %g)", -fx0, -fy0, fx, fy);
  NSDebugLLog(@"term", @"Normal font encoding %i", font_encoding);

  draw_all = 2;
}

- (void)setBoldFont:(NSFont *)bFont
{
  ASSIGN(boldFont, bFont);

  boldFont_encoding = [boldFont mostCompatibleStringEncoding];

  NSDebugLLog(@"term", @"Bold font encoding %i", boldFont_encoding);

  draw_all = 2;
}

- (int)scrollBufferLength
{
  return curr_sb_depth;
}

- (BOOL)setScrollBufferMaxLength:(int)lines
{
  if (max_sb_depth == lines) {
    return YES;
  }

  max_sb_depth = lines;
  
  if (lines == 0) {
    [self clearBuffer:self];
    alloc_sb_depth = 0;
    if (scrollback) {
      free(scrollback);
      scrollback = NULL;
    }
    return YES;
  }

  [self changeScrollBackBufferDepth:lines];
  
  return YES;
}

- (void)setScrollBottomOnInput:(BOOL)scrollBottom
{
  shouldScrollBottomOnInput = scrollBottom;
}

- (void)setCursorStyle:(NSUInteger)style
{
  cursorStyle = style;
}

- (void)setCharset:(NSString *)charsetName
{
  [terminalParser setCharset:charsetName];
}
- (void)setUseMulticellGlyphs:(BOOL)multicellGlyphs
{
  useMultiCellGlyphs = multicellGlyphs;
}
- (void)setDoubleEscape:(BOOL)doubleEscape
{
  [terminalParser setDoubleEscape:doubleEscape];
}
- (void)setAlternateAsMeta:(BOOL)altAsMeta
{
  [terminalParser setAlternateAsMeta:altAsMeta];
}

#pragma mark - Window Title

// ---
// Title (window, icon)
// ---

- (NSString *)xtermTitle
{
  return xtermTitle;
}

- (NSString *)xtermIconTitle
{
  return xtermIconTitle;
}

- (void)updateProgramPath
{
  NSString *childPath, *childText, *cmdPath, *cmdText, *command;
  NSData *cmdData;
  NSString *childPID;
  NSMutableArray *children;

  // fprintf(stderr, "--- updateProgramPath - %i\n", child_pid);

  if (child_pid == 0) {
    return;
  }

  childPID = [[NSNumber numberWithInt:child_pid] stringValue];
  children = [NSMutableArray new];
  // fprintf(stderr, "%s", childPID.cString);
  do {
    childPath = [NSString stringWithFormat:@"/proc/%@/task/%@/children", childPID, childPID];
    childText = [NSString stringWithContentsOfFile:childPath];

    [children setArray:[childText componentsSeparatedByString:@" "]];
    [children removeObjectIdenticalTo:@""];

    // if (children.count > 0 && [children.firstObject isEqualToString:@""] == NO) {
    if (children.isEmpty == NO) {
      childPID = children.firstObject;
      // fprintf(stderr, " > %s", childPID.cString);
    }
  } while (children.isEmpty == NO);
  [children release];
  // fprintf(stderr, "\n");
  // if (childPID.intValue == child_pid) {
  //   goto done;
  // }

  cmdPath = [NSString stringWithFormat:@"/proc/%@/cmdline", childPID];

  // Normalize `cmdline` contents - replace NULL's with spaces
  if ([[NSFileManager defaultManager] fileExistsAtPath:cmdPath] == NO) {
    return;
  }
  cmdData = [NSData dataWithContentsOfFile:cmdPath];
  char *data = (char *)[cmdData bytes];
  if (data == NULL) {
    return;
  }
  for (int i = 0; i < [cmdData length]; i++) {
    if (data[i] == 0) {
      data[i] = ' ';
    }
  }

  // Get command from `cmdline`
  command = [[NSString alloc] initWithBytes:[cmdData bytes]
                                     length:[cmdData length]
                                   encoding:NSASCIIStringEncoding];
  // NSLog(@"cmdline: `%@`", command);
  cmdText = [NSString stringWithString:[command componentsSeparatedByString:@" "].firstObject];
  [command release];

  if (cmdText && [cmdText isEqualToString:@""] == NO) {
    NSString *newProgramPath = [cmdText lastPathComponent];
    // if ([programPath isEqualToString:newProgramPath] == NO) {
      [programPath release];
      programPath = [[NSString alloc] initWithString:newProgramPath];
      // NSLog(@"New programPath: `%@`", programPath);
      [(TerminalWindowController *)[_window windowController]
          performSelectorOnMainThread:@selector(updateTitleBar:)
                           withObject:nil
                        waitUntilDone:YES];
  }
}

- (NSString *)programPath
{
  return programPath;
}

- (NSString *)deviceName
{
  NSString *ttyName;
  NSMutableArray *ttyPath = [[childTerminalName pathComponents] mutableCopy];

  [ttyPath removeObjectAtIndex:0];  // remove '/'
  [ttyPath removeObjectAtIndex:0];  // remove 'dev'
  ttyName = [ttyPath componentsJoinedByString:@"/"];
  [ttyPath release];

  return ttyName;
}

- (NSSize)windowSize
{
  return NSMakeSize(screen_width, screen_height);
}

- (BOOL)isUserProgramRunning
{
  return (master_fd == -1) || (tcgetpgrp(master_fd) == child_pid) ? NO : YES;
}

- (void)setIgnoreResize:(BOOL)ignore
{
  shouldIgnoreResize = ignore;
}

- (void)setBorderX:(float)x Y:(float)y
{
  border_x = x;
  border_y = y;
}

#pragma mark - Drag and Drop
// ---
// Drag and drop
// ---
+ (void)registerPasteboardTypes
{
  NSArray *types;

  types =
      [NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, NSFontPboardType, nil];

  [NSApp registerServicesMenuSendTypes:types returnTypes:nil];
}

#pragma mark - Menu
// ---
// Menu (Edit: Copy, Paste, Select All, Clear Buffer)
// ---
- (BOOL)validateMenuItem:(id<NSMenuItem>)menuItem
{
  NSString *itemTitle = [menuItem title];

  if ([itemTitle isEqualToString:@"Clear Buffer"] && (curr_sb_depth <= 0)) {
    return NO;
  }
  if ([itemTitle isEqualToString:@"Copy"] && (selection.length <= 0)) {
    return NO;
  }
  if ([itemTitle isEqualToString:@"Paste Selection"] && (selection.length <= 0)) {
    return NO;
  }
  if ([itemTitle isEqualToString:@"Copy Font"]) {
    // TODO
  }
  if ([itemTitle isEqualToString:@"Paste Font"]) {
    NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSFontPboard];
    if ([pb dataForType:NSFontPboardType] == nil) {
      return NO;
    }
  }

  return YES;
}

// Menu item "Edit > Clear Buffer"
- (void)clearBuffer:(id)sender
{
  curr_sb_depth = 0;
  curr_sb_position = 0;
  [self _updateScroller];
  [self setNeedsDisplay:YES];
}

- (void)benchmark:(id)sender
{
  int i;
  double t1, t2;
  NSRect r = [self frame];

  t1 = [NSDate timeIntervalSinceReferenceDate];
  total_draw = 0;
  for (i = 0; i < 100; i++) {
    draw_all = 2;
    [self lockFocus];
    [self drawRect:r];
    [self unlockFocusNeedsFlush:NO];
  }
  t2 = [NSDate timeIntervalSinceReferenceDate];
  t2 -= t1;
  fprintf(stderr, "%8.4f  %8.5f/redraw   total_draw=%i\n", t2, t2 / i, total_draw);
}

@end
