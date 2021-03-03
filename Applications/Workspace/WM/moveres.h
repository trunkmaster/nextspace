/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
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

#ifndef __WORKSPACE_WM_MOVERES__
#define __WORKSPACE_WM_MOVERES__

/* How many pixels to move before dragging windows and other objects */
#define MOVE_THRESHOLD 5

/* geometry displays */
#define WDIS_NEW		0	/* new style */
#define WDIS_CENTER		1	/* center of screen */
#define WDIS_TOPLEFT		2	/* top left corner of screen */
#define WDIS_FRAME_CENTER	3	/* center of the frame */
#define WDIS_TITLEBAR		4	/* titlebar */
#define WDIS_NONE		5

#endif /* __WORKSPACE_WM_MOVERES__ */
