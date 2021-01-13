/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2001 Dan Pascu
 *  Copyright (c) 2014 Window Maker Team
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#ifndef __WORKSPACE_WM_WCOLOR__
#define __WORKSPACE_WM_WCOLOR__

#include "wscreen.h"

typedef unsigned long WMPixel;

typedef struct W_Color {
  struct W_Screen *screen;

  XColor color;
  unsigned short alpha;
  short refCount;
  GC gc;
  struct {
    unsigned int exact:1;
  } flags;
} W_Color;

#define W_PIXEL(c)		(c)->color.pixel

WMColor* WMDarkGrayColor(WMScreen *scr);

WMColor* WMGrayColor(WMScreen *scr);

WMColor* WMBlackColor(WMScreen *scr);

WMColor* WMWhiteColor(WMScreen *scr);

void WMSetColorInGC(WMColor *color, GC gc);

GC WMColorGC(WMColor *color);

WMPixel WMColorPixel(WMColor *color);

void WMPaintColorSwatch(WMColor *color, Drawable d, int x, int y,
                        unsigned int width, unsigned int height);

void WMReleaseColor(WMColor *color);

WMColor* WMRetainColor(WMColor *color);

WMColor* WMCreateRGBColor(WMScreen *scr, unsigned short red,
                          unsigned short green, unsigned short blue,
                          Bool exact);

WMColor* WMCreateRGBAColor(WMScreen *scr, unsigned short red,
                           unsigned short green, unsigned short blue,
                           unsigned short alpha, Bool exact);

WMColor* WMCreateNamedColor(WMScreen *scr, const char *name, Bool exact);

RColor WMGetRColorFromColor(WMColor *color);

void WMSetColorAlpha(WMColor *color, unsigned short alpha);

unsigned short WMRedComponentOfColor(WMColor *color);

unsigned short WMGreenComponentOfColor(WMColor *color);

unsigned short WMBlueComponentOfColor(WMColor *color);

unsigned short WMGetColorAlpha(WMColor *color);

char* WMGetColorRGBDescription(WMColor *color);

#endif /* __WORKSPACE_WM_WCOLOR__ */
