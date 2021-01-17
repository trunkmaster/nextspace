/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
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

#ifndef __WORKSPACE_WM_WLABEL__
#define __WORKSPACE_WM_WLABEL__

#include "wfont.h"

typedef struct WMLabel {
	WMClass widgetClass;
	WMView *view;

	char *caption;

	WMColor *textColor;
	WMFont *font;		/* if NULL, use default */

	WMPixmap *image;

	struct {
		WMReliefType relief:3;
		WMImagePosition imagePosition:4;
		WMAlignment alignment:2;

		unsigned int noWrap:1;

		unsigned int redrawPending:1;
	} flags;
} WMLabel;
typedef struct WMLabel WMLabel;

/* ---[ WINGs/wlabel.c ]-------------------------------------------------- */

WMLabel* WMCreateLabel(WMWidget *parent);

void WMSetLabelWraps(WMLabel *lPtr, Bool flag);

void WMSetLabelImage(WMLabel *lPtr, WMPixmap *image);

WMPixmap* WMGetLabelImage(WMLabel *lPtr);

char* WMGetLabelText(WMLabel *lPtr);

void WMSetLabelImagePosition(WMLabel *lPtr, WMImagePosition position);

void WMSetLabelTextAlignment(WMLabel *lPtr, WMAlignment alignment);

void WMSetLabelRelief(WMLabel *lPtr, WMReliefType relief);

void WMSetLabelText(WMLabel *lPtr, const char *text);

WMFont* WMGetLabelFont(WMLabel *lPtr);

void WMSetLabelFont(WMLabel *lPtr, WMFont *font);

void WMSetLabelTextColor(WMLabel *lPtr, WMColor *color);

#endif /* __WORKSPACE_WM_WLABEL__ */
