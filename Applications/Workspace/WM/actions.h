/*
 *  Window Maker window manager
 *
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

#ifndef __WORKSPACE_WM_ACTIONS__
#define __WORKSPACE_WM_ACTIONS__

#include "window.h"

/* max. time to spend doing animations in seconds. If the animation
 * time exceeds this value, it is immediately finished. Usefull for
 * moments of high-load. DO NOT set *_DELAY_{Z,T,F} to zero!
 */
#define MAX_ANIMATION_TIME	         1     // misc.c, actions.c

/* Zoom animation */
#define MINIATURIZE_ANIMATION_FRAMES_Z   7     // actions.c
#define MINIATURIZE_ANIMATION_STEPS_Z    16    // actions.c
#define MINIATURIZE_ANIMATION_DELAY_Z    10000 // superfluous.c, actions.c

/* Twist animation */
#define MINIATURIZE_ANIMATION_FRAMES_T   12    // actions.c
#define MINIATURIZE_ANIMATION_STEPS_T    16    // actions.c
#define MINIATURIZE_ANIMATION_DELAY_T    20000 // actions.c
#define MINIATURIZE_ANIMATION_TWIST_T    0.5   // actions.c

/* Flip animation */
#define MINIATURIZE_ANIMATION_FRAMES_F   12    // actions.c
#define MINIATURIZE_ANIMATION_STEPS_F    16    // actions.c
#define MINIATURIZE_ANIMATION_DELAY_F    20000 // actions.c
#define MINIATURIZE_ANIMATION_TWIST_F    0.5   // actions.c

/* shade animation */
#define SHADE_STEPS_UF		5
#define SHADE_DELAY_UF		0

#define SHADE_STEPS_F		10
#define SHADE_DELAY_F		0

#define SHADE_STEPS_M		15
#define SHADE_DELAY_M		0

#define SHADE_STEPS_S		30
#define SHADE_DELAY_S		0

#define SHADE_STEPS_US		40
#define SHADE_DELAY_US		10

/**/
#define MAX_HORIZONTAL         (1 << 0)
#define MAX_VERTICAL           (1 << 1)
#define MAX_LEFTHALF           (1 << 2)
#define MAX_RIGHTHALF          (1 << 3)
#define MAX_TOPHALF            (1 << 4)
#define MAX_BOTTOMHALF         (1 << 5)
#define MAX_MAXIMUS            (1 << 6)
#define MAX_IGNORE_XINERAMA    (1 << 7)
#define MAX_KEYBOARD           (1 << 8)

/**/
#define SAVE_GEOMETRY_X        (1 << 0)
#define SAVE_GEOMETRY_Y        (1 << 1)
#define SAVE_GEOMETRY_WIDTH    (1 << 2)
#define SAVE_GEOMETRY_HEIGHT   (1 << 3)
#define SAVE_GEOMETRY_ALL      SAVE_GEOMETRY_X | SAVE_GEOMETRY_Y | SAVE_GEOMETRY_WIDTH | SAVE_GEOMETRY_HEIGHT

WWindow *wNextWindowToFocus(WWindow *wwin);
void wSetFocusTo(WScreen *scr, WWindow *wwin);

int wMouseMoveWindow(WWindow *wwin, XEvent *ev);
int wKeyboardMoveResizeWindow(WWindow *wwin);

void wMouseResizeWindow(WWindow *wwin, XEvent *ev);

void wShadeWindow(WWindow *wwin);
void wUnshadeWindow(WWindow *wwin);

void wIconifyWindow(WWindow *wwin);
void wDeiconifyWindow(WWindow *wwin);

void wSelectWindows(WScreen *scr, XEvent *ev);

void wSelectWindow(WWindow *wwin, Bool flag);
void wUnselectWindows(WScreen *scr);

void wMaximizeWindow(WWindow *wwin, int directions);
void wUnmaximizeWindow(WWindow *wwin);
void handleMaximize(WWindow *wwin, int directions);

void wHideAll(WScreen *src);
void wHideOtherApplications(WWindow *wwin);
void wShowAllWindows(WScreen *scr);

void wHideApplication(WApplication *wapp);
void wUnhideApplication(WApplication *wapp, Bool miniwindows,
                        Bool bringToCurrentWS);

void wRefreshDesktop(WScreen *scr);

void wArrangeIcons(WScreen *scr, Bool arrangeAll);

void wMakeWindowVisible(WWindow *wwin);

void wFullscreenWindow(WWindow *wwin);
void wUnfullscreenWindow(WWindow *wwin);

void animateResize(WScreen *scr, int x, int y, int w, int h, int fx, int fy, int fw, int fh);
void update_saved_geometry(WWindow *wwin);

#endif

