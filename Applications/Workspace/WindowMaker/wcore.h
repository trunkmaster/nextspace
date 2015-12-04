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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */


#ifndef WMCORE_H_
#define WMCORE_H_

#include "screen.h"

typedef struct WStacking {
    struct _WCoreWindow *above;
    struct _WCoreWindow *under;
    short window_level;
    struct _WCoreWindow *child_of;      /* owner for transient window */
} WStacking;

typedef struct _WCoreWindow {
    Window window;
    int width;		               /* size of the window */
    int height;
    WScreen *screen_ptr;	       /* ptr to screen of the window */

    WObjDescriptor descriptor;
    WStacking *stacking;	       /* window stacking information */
} WCoreWindow;


#include "pixmap.h"
WCoreWindow *wCoreCreateTopLevel(WScreen *screen, int x, int y, int width,
                                 int height, int bwidth);

WCoreWindow *wCoreCreate(WCoreWindow *parent, int x, int y,
                         int width, int height);
void wCoreDestroy(WCoreWindow *core);
void wCoreConfigure(WCoreWindow *core, int req_x, int req_y,
                    int req_w, int req_h);


#endif
