/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef __WORKSPACE_WM_DRAWING__
#define __WORKSPACE_WM_DRAWING__

#define DOUBLE_BUFFER   1

typedef struct {
    int x;
    int y;
} WMPoint;

typedef struct {
    unsigned int width;
    unsigned int height;
} WMSize;

typedef struct {
    WMPoint pos;
    WMSize size;
} WMRect;

#include "wview.h"
#include "wfont.h"

/* relief types */
typedef enum {
    WRFlat,
    WRSimple,
    WRRaised,
    WRSunken,
    WRGroove,
    WRRidge,
    WRPushed
} WMReliefType;

/* alignment types */
typedef enum {
    WALeft,
    WACenter,
    WARight,
    WAJustified		       /* not valid for textfields */
} WMAlignment;

/* image position */
typedef enum {
    WIPNoImage,
    WIPImageOnly,
    WIPLeft,
    WIPRight,
    WIPBelow,
    WIPAbove,
    WIPOverlaps
} WMImagePosition;

void WMDrawRelief(W_Screen *scr, Drawable d, int x, int y, unsigned int width,
                  unsigned int height, WMReliefType relief);

void WMDrawReliefWithGC(W_Screen *scr, Drawable d, int x, int y,
                        unsigned int width, unsigned int height,
                        WMReliefType relief,
                        GC black, GC dark, GC light, GC white);

void WMPaintTextAndImage(W_View *view, int wrap, WMColor *textColor,
                         W_Font *font, WMReliefType relief, const char *text,
                         WMAlignment alignment, W_Pixmap *image,
                         WMImagePosition position, WMColor *backColor, int ofs);

void WMPaintText(W_View *view, Drawable d, WMFont *font,  int x, int y,
                 int width, WMAlignment alignment, WMColor *color,
                 int wrap, const char *text, int length);

int WMGetTextHeight(WMFont *font, const char *text, int width, int wrap);

WMPoint WMMakePoint(int x, int y);
WMSize WMMakeSize(unsigned int width, unsigned int height);
WMRect WMMakeRect(int x, int y, unsigned int width, unsigned int height);

#endif /* __WORKSPACE_WM_DRAWING__ */
