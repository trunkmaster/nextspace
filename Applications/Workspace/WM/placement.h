/*  Window and icon placement on screen
 *
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  Window Maker window manager
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2013 Window Maker Team
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

#ifndef __WORKSPACE_WM_PLACEMENT__
#define __WORKSPACE_WM_PLACEMENT__

void PlaceIcon(WScreen *scr, int *x_ret, int *y_ret, int head);

/* Computes the intersecting length of two line sections */
int calcIntersectionLength(int p1, int l1, int p2, int l2);

/* Computes the intersecting area of two rectangles */
int calcIntersectionArea(int x1, int y1, int w1, int h1, int x2, int y2, int w2, int h2);

void PlaceWindow(WWindow *wwin, int *x_ret, int *y_ret, unsigned width, unsigned height);

void InteractivePlaceWindow(WWindow * wwin, int *x_ret, int *y_ret, unsigned width, unsigned height);

/* Set the points x and y inside the screen */
void get_right_position_on_screen(WScreen *scr, int *x, int *y, int size_x, int size_y);

#endif /* __WORKSPACE_WM_PLACEMENT__ */
