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

#ifndef __WORKSPACE_WM_WFRAME__
#define __WORKSPACE_WM_WFRAME__

#include "widgets.h"

/* frame title positions */
typedef enum {
  WTPNoTitle,
  WTPAboveTop,
  WTPAtTop,
  WTPBelowTop,
  WTPAboveBottom,
  WTPAtBottom,
  WTPBelowBottom
} WMTitlePosition;

typedef struct WMFrame {
	WMClass widgetClass;
	WMView *view;

	char *caption;
	WMColor *textColor;

	struct {
		WMReliefType relief:4;
		WMTitlePosition titlePosition:4;
	} flags;
} WMFrame;
typedef struct WMFrame WMFrame;

/* ---[ WINGs/wframe.c ]-------------------------------------------------- */

WMFrame* WMCreateFrame(WMWidget *parent);

void WMSetFrameTitlePosition(WMFrame *fPtr, WMTitlePosition position);

void WMSetFrameRelief(WMFrame *fPtr, WMReliefType relief);

void WMSetFrameTitle(WMFrame *fPtr, const char *title);

void WMSetFrameTitleColor(WMFrame *fPtr, WMColor *color);

#endif /* __WORKSPACE_WM_WFRAME__ */
