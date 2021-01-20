/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef __WORKSPACE_WM_WFONT__
#define __WORKSPACE_WM_WFONT__

#ifdef USE_PANGO
#include <pango/pango.h>
#endif

#include "wscreen.h"
#include "wcolor.h"

typedef struct WMFont {
    struct WMScreen *screen;

    struct _XftFont *font;

    short height;
    short y;
    short refCount;
    char *name;

#ifdef USE_PANGO
    PangoLayout *layout;
#endif
} WMFont;

#define WMFONTID(f) (f)->font->fid

/* ---[ WINGs/wfont.c ]--------------------------------------------------- */

/* Basic font styles. Used to easily get one style from another */
typedef enum WMFontStyle {
  WFSNormal = 0,
  WFSBold = 1,
  WFSItalic = 2,
  WFSBoldItalic = 3
} WMFontStyle;

Bool WMIsAntialiasingEnabled(WMScreen *scrPtr);

WMFont* WMCreateFont(WMScreen *scrPtr, const char *fontName);

WMFont* WMCopyFontWithStyle(WMScreen *scrPtr, WMFont *font, WMFontStyle style);

WMFont* WMRetainFont(WMFont *font);

void WMReleaseFont(WMFont *font);

char* WMGetFontName(WMFont *font);

unsigned int WMFontHeight(WMFont *font);

void WMSetWidgetDefaultFont(WMScreen *scr, WMFont *font);

void WMSetWidgetDefaultBoldFont(WMScreen *scr, WMFont *font);

WMFont* WMDefaultSystemFont(WMScreen *scrPtr);

WMFont* WMDefaultBoldSystemFont(WMScreen *scrPtr);

WMFont* WMSystemFontOfSize(WMScreen *scrPtr, int size);

WMFont* WMBoldSystemFontOfSize(WMScreen *scrPtr, int size);

void WMDrawString(WMScreen *scr, Drawable d, WMColor *color, WMFont *font,
                  int x, int y, const char *text, int length);

void WMDrawImageString(WMScreen *scr, Drawable d, WMColor *color,
                       WMColor *background, WMFont *font, int x, int y,
                       const char *text, int length);

int WMWidthOfString(WMFont *font, const char *text, int length);

#endif /* __WORKSPACE_WM_WFONT__ */
